#!/usr/bin/perl -w
#
# $Id: migrate_services.pl,v 1.7 2002/06/22 02:50:18 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# Heavily mangled by Bob Apthorpe sometime in June, 2002.

require 'migrate_common.ph';

$PROGRAM = "migrate_services.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

# keep Perl quiet
$use_stdout = 0;

&parse_args();
&open_files();

my %services = ();
my %portmap = ();
&parse_services(\%services, \%portmap);

my $service_ldif = &build_service_records(\%services, \%portmap);

if ($use_stdout) {
	print STDOUT $service_ldif;
} else {
	print OUTFILE $service_ldif;
}

close(INFILE);
if (OUTFILE ne STDOUT) { close(OUTFILE); }

##### Subroutines #####

sub parse_services
{
	my $Rh_services = shift;
	my $Rh_portmap = shift;

	# A note about $Rh_services:
	# $Rh_services is a reference to a hash of service
	# information. The structure is:
	# 
	# $Rh_services->{$port}{$servicename}{$proto}{'cn'} = $canonicalservicename;
	# $Rh_services->{$port}{$servicename}{$proto}{'aliases'}{$alias} = 1;
	#
	# so @ports = keys(%{$Rh_services});
	# @services_on_a_port = keys(%{$Rh_services->{$port}});
	#
	# Aliases are stored in a hash to keep them normalized, though
	# it's sort of a waste since the aliases are normalized again when
	# protocols are combined while creating records. It's not clear
	# you save any space by storing aliases as a list (allowing multiple
	# identical names to be stored until being normalized away at the
	# end) vs storing them as a hash (storing useless hash values
	# to keep the aliases normalized as keys.) It's also not clear
	# this is even worth worrying about...

	my %svcmap = ();
	my %protocols_found = ();

	my $card = '';
	readloop:
	while(defined($card = <INFILE>))
	{
		next readloop if ($card =~ m/^\s*#/o || $card eq "\n");
		$card =~ s/#.*//o;

		my ($servicename, $portproto, @aliases) = split(m/\s+/o, $card);
		my ($rawport, $proto) = split(m#[/,]#o, $portproto);

		# Find services specifying a port range (e.g. X11.)
		my $loport = '';
		my $hiport = '';
		if ($rawport =~ m#(\d+)-(\d+)#o) {
			$loport = $1;
			$hiport = $2;
		} else {
			$loport = int($rawport);
			$hiport = $loport;
		}
	
		$hiport = $loport if (!defined($hiport) || ($hiport < $loport));

		# Track the number of unique ports used by a service.
		foreach ($loport .. $hiport) {
			$Rh_portmap->{$servicename}{$proto}{$_} = 1;
		}

		my $indivport = '';
		foreach $indivport ($loport .. $hiport) {
			unless (exists($Rh_services->{$indivport}{$servicename}{$proto}{'cn'})) {
				# We've never seen this port/protocol pair
				# before so we take the first occurence of
				# the name as the canonical one, in case
				# we see repeated listings later (see below)

				$svcmap{$indivport}{$proto} = $servicename;
				$Rh_services->{$indivport}{$servicename}{$proto}{'cn'} = $servicename;
				foreach ($servicename, @aliases) {
					$Rh_services->{$indivport}{$servicename}{$proto}{'aliases'}{$_} = 1;
				}
			} else {
				# We've seen this port/protocol pair
				# before so we'll add the service name and
				# any aliases as aliases in the original
				# (canonical) record.

				my $canonical_svc = $svcmap{$indivport}{$proto};
				foreach ($servicename, @aliases) {
					$Rh_services->{$indivport}{$canonical_svc}{$proto}{'aliases'}{$_} = 1;
				}
			}
		}
	}

	return;
}

sub build_service_records
{
	my $Rh_services = shift;
	my $Rh_portmap = shift;

	foreach $port (sort {$a <=> $b} (keys %{$Rh_services})) {
		foreach $servicename (keys %{$Rh_services->{$port}}) {
			my @protocols = (keys %{$Rh_services->{$port}{$servicename}});
			my %tmpaliases = ();

			# Note on the suffix:
			# If a service name applies to a range of
			# ports, add a suffix to the cn and the aliases
			# to ensure unique dn's for each service. The NIS
			# schema that defines ipService (1.3.6.1.1.1.2.3)
			# and ipServicePort (1.3.6.1.1.1.1.15) only
			# allows a single port to be associated with a
			# service name so we have to mangle the cn to
			# differentiate the dn's for each port. This is
			# ugly; the alternative is to change the schema or
			# the format of the services file. "Irresistable
			# Force, meet Immovable Object..."

			my $suffix = '';
			foreach $proto (@protocols) {
				# Only add suffix if it's absolutely necessary
				if (scalar(keys(%{$Rh_portmap->{$servicename}{$proto}})) > 1) {
					$suffix = "+ipServicePort=" . &escape_metacharacters($port);
				}

				# Normalize aliases across protocols. Yet
				# another uncomfortable compromise.
				foreach (keys %{$Rh_services->{$port}{$servicename}{$proto}{'aliases'}}) {
					$tmpaliases{$_} = 1;
				}
			}

			my @aliases = keys(%tmpaliases);
			
			# Finally we build LDIF records for services.
			$svcrecords .= "dn: cn=" . &escape_metacharacters($servicename)
				. $suffix
				. ",$NAMINGCONTEXT\n"
				. "objectClass: ipService\n"
				. "objectClass: top\n"
				. "ipServicePort: $port\n"
				. join('', map { "ipServiceProtocol: $_\n" } (@protocols))
				. join('', map { "cn: $_\n" } (@aliases))
				. "\n";
		}
	}

	return $svcrecords;

}
__END__

=head1 NAME

migrate_services.pl - translate /etc/services into LDIF format for easy migration into LDAP.

=head1 SYNOPSIS

 migrate_services.pl /etc/services /tmp/services.ldif

which produces LDIF entries similar to:

 dn: cn=rtmp,ou=Services,dc=padl,dc=com
 objectClass: ipService
 objectClass: top
 ipServicePort: 1
 ipServiceProtocol: ddp
 cn: rtmp
  
 dn: cn=tcpmux,ou=Services,dc=padl,dc=com
 objectClass: ipService
 objectClass: top
 ipServicePort: 1
 ipServiceProtocol: udp
 ipServiceProtocol: tcp
 cn: tcpmux
  
 dn: cn=nbp,ou=Services,dc=padl,dc=com
 objectClass: ipService
 objectClass: top
 ipServicePort: 2
 ipServiceProtocol: ddp
 cn: nbp
  
 dn: cn=compressnet+ipServicePort=2,ou=Services,dc=padl,dc=com
 objectClass: ipService
 objectClass: top
 ipServicePort: 2
 ipServiceProtocol: udp
 ipServiceProtocol: tcp
 cn: compressnet

 dn: cn=discard,ou=Services,dc=padl,dc=com
 objectClass: ipService
 objectClass: top
 ipServicePort: 9
 ipServiceProtocol: udp
 ipServiceProtocol: tcp
 cn: null
 cn: sink
 cn: Discard
 cn: discard

=head1 USAGE

 migrate_services.pl services_file [ translated_file.ldif ]

=head1 DESCRIPTION

migrate_services.pl parses /etc/services into LDIF format according to the NIS LDAP schema. 

Services spanning a range of ports are uniquely identified by using
multivalued RDNs. Due to a limitation in the NIS schema, there is an
assumed one-to-one association between port and service name (though,
oddly, multiple protocol names are allowed.)

=head1 HOMEPAGE

 Module Home: http://www.padl.com/OSS/MigrationTools.html

=head1 AUTHOR

 Luke Howard
 Heavily mangled by Bob Apthorpe sometime in June, 2002.

=head1 LICENSE

 Copyright (c) 1997 Luke Howard.
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. All advertising materials mentioning features or use of this software
    must display the following acknowledgement:
        This product includes software developed by Luke Howard.
 4. The name of the other may not be used to endorse or promote products
    derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE LUKE HOWARD ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED.  IN NO EVENT SHALL LUKE HOWARD BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

=cut
