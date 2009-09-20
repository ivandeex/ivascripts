<?php
/****************************************************************
 ** $Id$
 ** Contribution Name: Bugzilla to Redmine Migration Script
 ** Contribution Version: 1.0
 ** Author Name: Robert Heath
 ** Author E-Mail Address: robert@robertheath.net
 ** Author Website: www.robertheath.net
 **
 ** !!! IMPORTANT !!!
 ** Executing this script will clean out your Redmine database! Only
 ** run this script on a fresh install of Redmine! This script
 ** will migrate users, projects, bugs, comments, categories, 
 ** components, and attachments.
 ** 
 ** The Bugzilla installation and Redmine installation sections are
 ** required. All other configuration variables can be adjusted to
 ** match your system/preferences.
 ** 
 ** !!! WARNING !!!
 ** ONLY RUN THIS SCRIPT ON A FRESH INSTALL OF REDMINE!!!
 ** 
 ** BACKUP YOUR BUGZILLA AND REDMINE DATABASES BEFORE EXECUTING
 ** THIS SCRIPT!!!
 ** 
 ** This script is based on the one we used to migrate our production
 ** system. The script was modified to make it more generic so that
 ** it could be used by anyone. Use at your own risk.
 **
 ***************************************************************/

// Report all PHP errors
error_reporting(E_ALL);

/******************* Configuration Section *********************/

	// Bugzilla installation info
	$bugzillaDBHostname = "localhost";
	$bugzillaDBUser = "bugs";
	$bugzillaDBPassword = "bugs";
	$bugzillaDBName = "bugs";
	$bugzillaURL = "http://bugzilla.ourdom.com/bugzilla";

	// Redmine installation info
	$redmineDBHostname = "localhost";
	$redmineDBUser = "redmine";
	$redmineDBPassword = "redmine";
	$redmineDBName = "redmine";
	$redmineInstallPath = "/var/www/redmine";

	// Project modules to be enabled
	$enableIssueTracking = true;
	$enableTimeTracking = true;
	$enableNews = true;
	$enableDocuments = true;
	$enableFiles = true;
	$enableWiki = true;
	$enableRepository = true;
	$enableBoards = true;

	// Bugzilla priority to Redmine priority map
	$issuePriorities = array(
				"Utmost" => 7,
				"High" => 6,
				"Medium" => 4,
				"Low" => 3,
				"Optional" => 2);

	// Bugzilla severity to Redmine tracker map
	$issueTrackers = array(	"blocker"     => 1,
				"critical"    => 1,
				"major"       => 1,
				"normal"      => 1,
				"minor"       => 1,
				"trivial"     => 1,
				"enhancement" => 2);

	// Bugzilla status to Redmine status map
        $issueStatus = array(	"UNCONFIRMED"   => 1,
				"NEW"           => 1,
				"ASSIGNED"      => 2,
				"REOPENED"      => 7,
				"RESOLVED"      => 5,
				"VERIFIED"      => 2,
				"CLOSED"        => 5);

	$adminLoginPattern = "/^root@/";

	$migrateAttachmentContents = false;

	$useDeliverables = false;
	$useNextIssues = false;
	$useQuestions = false;

/***************** End Configuration Section ******************/

	// Determine if the databases from Redmine and Bugzilla are on the same server
        $shareDB = true;
	if ($bugzillaDBHostname != $redmineDBHostname)
		$shareDB = false;

	// Connect to bugzilla database
	$link = mysql_connect($bugzillaDBHostname, $bugzillaDBUser, $bugzillaDBPassword);
	if (!$link)
		die('Could not connect: ' . mysql_error());
		
	$db_selected = mysql_select_db($bugzillaDBName, $link);
	if (!$db_selected)
		die ('Can\'t use ($bugzillaDBName : ' . mysql_error());	

	// Map Bugzilla Product info to Redmine Project info
	$projects = array();

	$sql = "SELECT products.id, 
		       products.name, 
		       products.description, 
		       products.classification_id, 
		       classifications.name as classification_name
		   FROM products, classifications 
		   WHERE products.classification_id = classifications.id";

	$result = mysql_query($sql) or die(mysql_error().$sql);	
	while($row = mysql_fetch_array($result)) {
		$project = new stdClass();
		$project->id			= $row['id'];
		$project->name 			= $row['name'];
		$project->description		= $row['description'];
		$project->is_public		= 1;
		$project->projects_count 	= 0;
		$project->created_on		= "2007-01-01 12:00:00";
		$project->updated_on		= "2009-01-01 12:00:00";
		
		$projects[$row['id']] = $project;
	}
	
	// Map Bugzilla Versions to Redmine Versions
	$versions = array();
	$versionNames = array();

	$sql = "SELECT id, 
		       product_id AS project_id, 
		       value AS name 
		   FROM versions";

        $result = mysql_query($sql) or die(mysql_error().$sql);
        while($row = mysql_fetch_array($result)) {
                $versionNames[$row['project_id']][$row['name']] = $row['id'];
                $version = new stdClass();
                $version->id            = $row['id'];
                $version->project_id	= $row['project_id'];
                $version->name          = $row['name'];

                $versions[$row['id']] = $version;
        }
	
	// Map Bugzilla User info to Redmine User info
	$users = array();
	
	$sql = "SELECT userid, login_name, realname, disabledtext FROM profiles";

	$result = mysql_query($sql) or die(mysql_error().$sql);	
	while($row = mysql_fetch_array($result)) {
		$status = 1;
		if (!empty($row['disabledtext'])) $status = 3;
		
		if (!empty($row['realname'])) {
			$name = split(" ", $row['realname']);
			$firstname	= $name[0];
			$lastname	= $name[1];
		} else {
			$firstname	= "";
			$lastname	= "";
		}
		
		$user = new stdClass();
		$user->id		= $row['userid'];
		$user->login 		= $row['login_name'];
		$user->mail		= $row['login_name'];
		$user->firstname	= $firstname;
		$user->lastname		= $lastname;
		$user->language		= "en";
		$user->mail_notification = "0";
		$user->status		= $status;
		$user->admin		= preg_match($adminLoginPattern, $user->login);
		$user->hashed_password = sha1($user->login); // PASSWORD EQUAL TO LOGIN NAME
		if ($user->admin == 1)
			echo $user->login . " becomes administrator\n";

		$users[$row['userid']] = $user;
	}

	// Map Bugzilla Groups to Redmine Members
	$members = array();
	$sql = "SELECT DISTINCT user_group_map.user_id,
				group_control_map.product_id AS project_id 
		   FROM group_control_map, user_group_map
		   WHERE group_control_map.group_id = user_group_map.group_id";

        $result = mysql_query($sql) or die(mysql_error().$sql);
        while($row = mysql_fetch_array($result)) {
                $member = new stdClass();
                $member->user_id        	= $row['user_id'];
                $member->project_id		= $row['project_id'];
                $member->role_id       		= "6";
                $member->created_on	        = "2007-01-01 12:00:00";
                $member->mail_notification	= "0";

                $members[] = $member;
        }

	// Map Bugzilla Components to Redmine Categories
	$categories = array();
	$sql = "SELECT id, 
		       product_id as project_id, 
		       name, 
		       initialowner as assigned_to_id 
		  FROM components";

        $result = mysql_query($sql) or die(mysql_error().$sql);
        while($row = mysql_fetch_array($result)) {
                $category = new stdClass();
                $category->id                   = $row['id'];
                $category->project_id           = $row['project_id'];
                $category->name                 = $row['name'];
                $category->assigned_to_id	= $row['assigned_to_id'];

                $categories[$row['id']] = $category;
	}

	// Map Bugzilla Bugs and Comments to Redmine Issues and Journals
	$issues = array();
	$journals = array();

	$bug_id = 0;
	
	$sql = "SELECT bugs.bug_id, 
		       bugs.assigned_to, 
		       bugs.bug_status, 
		       bugs.creation_ts, 
		       bugs.short_desc, 
		       bugs.product_id, 
		       bugs.reporter, 
		       bugs.version,
		       bugs.resolution, 
		       bugs.estimated_time,
		       bugs.remaining_time,
		       bugs.deadline, 
		       bugs.bug_severity,
		       bugs.priority,
		       bugs.component_id,
		       bugs.status_whiteboard AS whiteboard, 
		       bugs.bug_file_loc AS url,
		       longdescs.comment_id, 
		       longdescs.thetext, 
		       longdescs.bug_when, 
		       longdescs.who, 
		       longdescs.isprivate
		   FROM bugs, longdescs 
		   WHERE bugs.bug_id = longdescs.bug_id
		   ORDER BY bugs.creation_ts, longdescs.bug_when";

	$result = mysql_query($sql) or die(mysql_error().$sql);	
	while($row = mysql_fetch_array($result)) {
		if ($row['bug_id'] != $bug_id) {
			$duedate = NULL;
			if ($row['deadline'] != NULL && $row['deadline'] != "") 
				$duedate = date("Y-m-d",strtotime($row['deadline']));
			
			$issue = new stdClass();
			$issue->id			= $row['bug_id'];
			$issue->project_id 		= $row['product_id'];
			$issue->subject			= $row['short_desc'];
			$issue->description		= $row['thetext'];
			$issue->assigned_to_id		= $row['assigned_to'];
			$issue->author_id		= $row['reporter'];
			$issue->created_on		= $row['creation_ts'];
			$issue->private			= $row['isprivate'];
			$issue->updated_on		= date("Y-m-d H:i:s");
			$issue->start_date		= date("Y-m-d",strtotime($row['creation_ts']));
			$issue->estimated_hours		= $row['estimated_time'];
			$issue->due_date		= $duedate;
			$issue->priority_id		= $issuePriorities[$row['priority']];
                        $issue->fixed_version_id        = $versionNames[$row['product_id']][$row['version']];
			$issue->category_id		= $row['component_id'];
			$issue->tracker_id		= $issueTrackers[$row['bug_severity']];
			$issue->status_id		= $issueStatus[$row['bug_status']];
                        $issue->whiteboard              = $row['whiteboard'];
                        $issue->url               	= $row['url'];

			$sql2 = "SELECT * FROM bug_group_map WHERE bug_id = " . $row['bug_id']
				. " AND (group_id = 14 OR group_id = 21)";
			$result2 = mysql_query($sql2) or die(mysql_error().$sql2);
			
			if ($row2 = mysql_fetch_array($result2)) $issue->private = "1";
		
			$issues[$row['bug_id']] = $issue;
		} else {
			$notes = $row['thetext'];
			if ($row['isprivate'] == "1") 
				$notes = "*Private Comment:: " . 
					 "See \"Bugzilla\":$bugzillaURL/show_bug.cgi?id=".$row['bug_id']." for more info*";

			$journal = new stdClass();
			$journal->id			= $row['comment_id'];
			$journal->journalized_id	= $row['bug_id'];
			$journal->journalized_type	= "Issue";
			$journal->user_id	 	= $row['who'];
			$journal->notes	 		= $notes;
			$journal->created_on		= $row['bug_when'];
		
			$journals[$row['comment_id']] 	= $journal;
		}
		
		$bug_id = $row['bug_id'];
	}

	// Map Bugzilla CC to Redmine Watchers
        $watchers = array();

        $sql = "SELECT bug_id, who FROM cc";

	$result = mysql_query($sql) or die(mysql_error().$sql);
	while($row = mysql_fetch_array($result)) {
		$watcher = new stdClass();
		$watcher->watchable_id		= $row['bug_id'];
		$watcher->user_id		= $row['who'];
		$watcher->watchable_type	= "Issue";

		$watchers[] = $watcher;
	}

	
	// Map Bugzilla Dependencies to Redmine Relations and Duplicates
	$relations = array();

	$sql = "SELECT blocked, dependson FROM dependencies";

	$result = mysql_query($sql) or die(mysql_error().$sql);
        while($row = mysql_fetch_array($result)) {
                $relation = new stdClass();
                $relation->issue_from_id	= $row['blocked'];
                $relation->issue_to_id		= $row['dependson'];
                $relation->relation_type	= "blocks";

                $relations[] = $relation;
        }

        $sql = "SELECT dupe_of, dupe FROM duplicates";

        $result = mysql_query($sql) or die(mysql_error().$sql);
        while($row = mysql_fetch_array($result)) {
                $relation = new stdClass();
                $relation->issue_from_id        = $row['dupe_of'];
                $relation->issue_to_id          = $row['dupe'];
                $relation->relation_type        = "duplicates";

                $relations[] = $relation;
        }

	// Map Bugzilla Attachments to Redmine Attachments
	$attachments = array();

	$sql = "SELECT  attachments.attach_id,
			attachments.bug_id,
			attachments.filename,
			attachments.mimetype,
			attachments.submitter_id,
			attachments.creation_ts,
			attachments.description
		   FROM attachments";

	$result = mysql_query($sql) or die(mysql_error().$sql);	
	while($row = mysql_fetch_array($result)) {

		$disk_filename = str_replace(" ","_",$row['filename']);
		$disk_filename = str_replace("#","",$disk_filename);
		$disk_filename = str_replace("(","",$disk_filename);
		$disk_filename = str_replace(")","",$disk_filename);

		$attachment = new stdClass();
		$attachment->id			= $row['attach_id'];
		$attachment->container_id 	= $row['bug_id'];
		$attachment->container_type	= "Issue";
		$attachment->filename		= $row['filename'];
		$attachment->content_type	= $row['mimetype'];
		$attachment->digest		= "";
		$attachment->downloads		= 0;
		$attachment->author_id		= $row['submitter_id'];
		$attachment->created_on		= $row['creation_ts'];
		$attachment->description	= $row['description'];

		$attachment->disk_filename	= $disk_filename;
		$attachment->redmine_filename	= $redmineInstallPath . "/files/" . $disk_filename;
		$attachment->filesize		= filesize($attachment->redmine_filename);

		$attachments[$row['attach_id']] = $attachment;
	}

	if ($migrateAttachmentContents) {
		echo count($attachments) . " attachment files to migrate..";
		foreach ($attachments as $key => $attachment) {

			$sql2 = "SELECT attach_data.thedata FROM attach_data
				WHERE attach_data.id = " . $attachment->id;
			$result2 = mysql_query($sql2) or die(mysql_error().$sql2);
			while($row2 = mysql_fetch_array($result2)) {
				$contents2 = $row2['thedata'];
				$fp = fopen($attachment->redmine_filename, 'w') or die("can't open file");
				if (fwrite($fp, $contents2) === FALSE)
					echo "Cannot write to file ($filename)\n";
				fclose($fp);
				$attachments[$key]->filesize = filesize($attachment->redmine_filename);
			}
		}
		$contents2 = "";
		echo "..done\n";
	}

	// Connect to Redmine database
	if ($shareDB) {
		$link = mysql_connect($redmineDBHostname, $redmineDBUser, $redmineDBPassword);
        	if (!$link) die('Could not connect: ' . mysql_error());
	}

        $db_selected = mysql_select_db($redmineDBName, $link);
        if (!$db_selected) die ('Can\'t use ($redmineDBName : ' . mysql_error());

	// Create Redmine Project from Bugzilla Product
	echo "Emptying Project tables.\n";
	
	$sql = "DELETE FROM projects";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	$sql = "DELETE FROM projects_trackers";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM enabled_modules";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	$sql = "DELETE FROM boards";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM custom_fields_projects";
	$result = mysql_query($sql) or die(mysql_error().$sql);
			
	$sql = "DELETE FROM documents";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	if ($useDeliverables) {
		$sql = "DELETE FROM deliverables";
		$result = mysql_query($sql) or die(mysql_error().$sql);
	}

	$sql = "DELETE FROM news";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM news";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM queries";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM repositories";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM time_entries";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM wiki_content_versions";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM wiki_contents";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM wiki_pages";
	$result = mysql_query($sql) or die(mysql_error().$sql);
	
	$sql = "DELETE FROM wiki_redirects";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM wikis";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	echo count($projects) . " Projects to import.\n";
	foreach ($projects as $key => $project) {
		$continue = true;

		$sql = "SELECT * FROM projects
			WHERE id = " . $project->id;

		$result = mysql_query($sql) or die(mysql_error().$sql);	
		if ($row = mysql_fetch_array($result)) $continue = false;

		if ($continue) {	
			$identifier = strtolower($project->name);
			$identifier = str_replace(" ", "-", $identifier);
                        $identifier = str_replace("", "", $identifier);

			$length = strlen($identifier);
			if ($length > 20) $length = "20";
			$identifier = substr($identifier, 0, $length);

			$sql = "INSERT INTO projects (id, 
						      name, 
						      description,
						      is_public,
						      projects_count,
						      identifier,
						      created_on,
						      updated_on)
					VALUES (" . $project->id . ", 
						'" . mysql_real_escape_string($project->name) . "', 
						'" . mysql_real_escape_string($project->description) . "', 
						" . $project->is_public . ", 
						" . $project->projects_count . ", 
						'" . $identifier . "',
						'" . mysql_real_escape_string($project->created_on) . "', 
						'" . mysql_real_escape_string($project->updated_on) . "')";
					
			$result = mysql_query($sql) or die(mysql_error().$sql);

			$sql = "INSERT INTO projects_trackers (project_id, tracker_id) VALUES (" . $project->id . ", 1)";
			$result = mysql_query($sql) or die(mysql_error().$sql);
			$sql = "INSERT INTO projects_trackers (project_id, tracker_id) VALUES (" . $project->id . ", 2)";
			$result = mysql_query($sql) or die(mysql_error().$sql);
			$sql = "INSERT INTO projects_trackers (project_id, tracker_id) VALUES (" . $project->id . ", 4)";
			$result = mysql_query($sql) or die(mysql_error().$sql);

			if ($enableIssueTracking) {
				$sql = "INSERT INTO enabled_modules (project_id, name) VALUES ("
					. $project->id . ", 'issue_tracking')";
				$result = mysql_query($sql) or die(mysql_error().$sql);
			}

                        if ($enableTimeTracking) {
				$sql = "INSERT INTO enabled_modules (project_id, name) VALUES (" . $project->id . ", 'time_tracking')";
				$result = mysql_query($sql) or die(mysql_error().$sql);
			}

                        if ($enableNews) {
				$sql = "INSERT INTO enabled_modules (project_id, name) VALUES (" . $project->id . ", 'news')";
				$result = mysql_query($sql) or die(mysql_error().$sql);
			}

                        if ($enableDocuments) {
				$sql = "INSERT INTO enabled_modules (project_id, name) VALUES (" . $project->id . ", 'documents')";
				$result = mysql_query($sql) or die(mysql_error().$sql);
			}

                        if ($enableFiles) {
				$sql = "INSERT INTO enabled_modules (project_id, name) VALUES (" . $project->id . ", 'files')";
				$result = mysql_query($sql) or die(mysql_error().$sql);
			}

                        if ($enableWiki) {
				$sql = "INSERT INTO enabled_modules (project_id, name) VALUES (" . $project->id . ", 'wiki')";
				$result = mysql_query($sql) or die(mysql_error().$sql);
			}

                        if ($enableRepository) {
				$sql = "INSERT INTO enabled_modules (project_id, name) VALUES (" . $project->id . ", 'repository')";
				$result = mysql_query($sql) or die(mysql_error().$sql);
			}

                        if ($enableBoards) {
				$sql = "INSERT INTO enabled_modules (project_id, name) VALUES (" . $project->id . ", 'boards')";
				$result = mysql_query($sql) or die(mysql_error().$sql);
			}
		}
	}

	// Create Redmine Versions for Bugzilla Versions
        echo "Emptying Versions tables.\n";

        $sql = "DELETE FROM versions";
        $result = mysql_query($sql) or die(mysql_error().$sql);

        echo count($versions) . " Versions to import.\n";
        foreach ($versions as $version) {
        	$sql = "INSERT INTO versions (id,
                                              project_id,
                                              name)
                        	VALUES (" . $version->id . ",
                                        " . $version->project_id . ",
                                        '" . mysql_real_escape_string($version->name) . "')";

                $result = mysql_query($sql) or die(mysql_error().$sql);
	}

	// Create Redmine User from Bugzilla User
	echo "Emptying User tables.\n";

	$sql = "DELETE FROM users";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	$sql = "DELETE FROM user_preferences";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	$sql = "DELETE FROM members";
	$result = mysql_query($sql) or die(mysql_error().$sql);
		
	$sql = "DELETE FROM messages";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	if ($useNextIssues) {
		$sql = "DELETE FROM next_issues";
		$result = mysql_query($sql) or die(mysql_error().$sql);
	}

	if ($useQuestions) {
		$sql = "DELETE FROM questions";
		$result = mysql_query($sql) or die(mysql_error().$sql);
	}

	$sql = "DELETE FROM tokens";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	$sql = "DELETE FROM watchers";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	echo count($users) . " Users to import.\n";
	foreach ($users as $key=>$user) {
		$continue = true;

		$sql = "SELECT * FROM users WHERE id = " . $user->id;

		$result = mysql_query($sql) or die(mysql_error().$sql);	
		if ($row = mysql_fetch_array($result)) $continue = false;

		if ($continue) {			
			$sql = "INSERT INTO users (id, 
						   login, 
						   mail, 
						   firstname,
						   lastname,
						   language,
						   mail_notification,
						   hashed_password,
						   admin,
						   status)
					VALUES (" . $user->id . ", 
						'" . mysql_real_escape_string($user->login) . "', 
						'" . mysql_real_escape_string($user->mail) . "', 
						'" . mysql_real_escape_string($user->firstname) . "', 
						'" . mysql_real_escape_string($user->lastname) . "', 
						'" . mysql_real_escape_string($user->language) . "', 
						" . $user->mail_notification . ",
						'" . $user->hashed_password . "',
						" . $user->admin . ",
						" . $user->status . ")";
					
			$result = mysql_query($sql) or die(mysql_error().$sql);

			$sql = "INSERT INTO user_preferences (user_id,
							      others)
					VALUES (" . $user->id . ",
						'--- \n:comments_sorting: asc\n:no_self_notified: true\n')";

                        $result = mysql_query($sql) or die(mysql_error().$sql);
		}
	}
	
	// Create Redmine Issue from Bugzilla Bug
	echo "Emptying Issue tables.\n";

	$sql = "DELETE FROM issues";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	$sql = "DELETE FROM issue_relations";
	$result = mysql_query($sql) or die(mysql_error().$sql);

        $sql = "DELETE FROM custom_values";
        $result = mysql_query($sql) or die(mysql_error().$sql);

	echo count($issues) . " Issues to import.\n";
	foreach ($issues as $key=>$issue) {
		$continue = true;

		$sql = "SELECT * FROM issues WHERE id = " . $issue->id;

		$result = mysql_query($sql) or die(mysql_error().$sql);	
		if ($row = mysql_fetch_array($result)) $continue = false;
			
		if ($continue) {			
			$sql = "INSERT INTO issues (id, 
						    project_id, 
						    subject, 
						    description,
						    assigned_to_id,
						    author_id,
						    created_on,
						    updated_on,
						    start_date,
						    estimated_hours,
						    due_date,
						    priority_id,
						    fixed_version_id,
						    category_id,
						    tracker_id,
						    status_id )
					VALUES (" . $issue->id . ", 
						" . $issue->project_id . ", 
						'" . mysql_real_escape_string($issue->subject) . "', 
						'" . mysql_real_escape_string($issue->description) . "', 
						" . $issue->assigned_to_id . ", 
						" . $issue->author_id . ", 
						'" . mysql_real_escape_string($issue->created_on) . "', 
						'" . mysql_real_escape_string($issue->updated_on) . "', 
						'" . mysql_real_escape_string($issue->start_date) . "', 
						'" . mysql_real_escape_string($issue->estimated_hours) . "', 
						'" . mysql_real_escape_string($issue->due_date) . "', 
						" . $issue->priority_id . ", 
                                                " . $issue->fixed_version_id . ",
                                                '" . $issue->category_id . "',
						" . $issue->tracker_id . ", 
						" . $issue->status_id . ")";
			
			$result = mysql_query($sql) or die(mysql_error().$sql);

			if (!empty($issue->url)) {
				$sql = "INSERT INTO custom_values (customized_type,
								   customized_id,
								   custom_field_id,
								   value)
						VALUES ('Issue',
							" . $issue->id . ",
							2,
							'" . mysql_real_escape_string($issue->url) . "')";

				$result = mysql_query($sql) or die(mysql_error().$sql);
			}
		}
	}


        // Create Redmine Members from Bugzilla Groups
        echo "Emptying Members tables.\n";

        $sql = "DELETE FROM members";
        $result = mysql_query($sql) or die(mysql_error().$sql);

        echo count($members) . " Members to import.\n";
        foreach ($members as $key=>$member) {
                $sql = "INSERT INTO members (user_id,
                                             project_id,
                                             role_id,
                                             created_on,
					     mail_notification)
				VALUES (" . $member->user_id . ",
                                        " . $member->project_id . ",
                                        " . $member->role_id . ",
                                        '" . $member->created_on . "',
					" . $member->mail_notification . ")";

                $result = mysql_query($sql) or die(mysql_error().$sql);
        }

	// Create Redmine Categories from Bugzilla Components
	echo "Emptying Category tables.\n";

        $sql = "DELETE FROM issue_categories";
        $result = mysql_query($sql) or die(mysql_error().$sql);

        echo count($categories) . " Categories to import.\n";
        foreach ($categories as $key=>$category) {
        	$sql = "INSERT INTO issue_categories (id,
                                                      project_id,
                                                      name,
                                                      assigned_to_id)
                                VALUES (" . $category->id . ",
                                        " . $category->project_id . ",
                                        '" . mysql_real_escape_string($category->name) . "',
                                        " . $category->assigned_to_id . ")";

                $result = mysql_query($sql) or die(mysql_error().$sql);
        }

        // Create Redmine Watchers from Bugzilla CC
        echo "Emptying Watchers tables.\n";

        $sql = "DELETE FROM watchers";
        $result = mysql_query($sql) or die(mysql_error().$sql);

        echo count($watchers) . " Watchers to import.\n";
        foreach ($watchers as $key=>$watcher) {
                $sql = "INSERT INTO watchers (watchable_id,
                                             user_id,
                                             watchable_type)
                                VALUES (" . $watcher->watchable_id . ",
                                        " . $watcher->user_id . ",
                                        '" . mysql_real_escape_string($watcher->watchable_type) . "')";

                $result = mysql_query($sql) or die(mysql_error().$sql);
        }


        // Create Redmine Relations from Bugzilla Dependencies and Duplicates
        echo "Emptying Relations tables.\n";

        $sql = "DELETE FROM issue_relations";
        $result = mysql_query($sql) or die(mysql_error().$sql);

        echo count($relations) . " Relations to import.\n";
        foreach ($relations as $key=>$relation) {
                $sql = "INSERT INTO issue_relations (issue_from_id,
                                                     issue_to_id,
                                                     relation_type)
                                VALUES (" . $relation->issue_from_id . ",
                                        " . $relation->issue_to_id . ",
                                        '" . mysql_real_escape_string($relation->relation_type) . "')";

                $result = mysql_query($sql) or die(mysql_error().$sql);
        }

	// Create Redmine Attachments from Bugzilla Attachments
	echo "Emptying Attachment tables.\n";

	$sql = "DELETE FROM attachments";
	$result = mysql_query($sql) or die(mysql_error().$sql);
	
	echo count($attachments) . " Attachments to import.\n";
	foreach ($attachments as $key=>$attachment) {
		$continue = true;

		$sql = "SELECT * FROM attachments WHERE id = " . $attachment->id;

		$result = mysql_query($sql) or die(mysql_error().$sql);	
		if ($row = mysql_fetch_array($result)) $continue = false;

		if ($continue) {			
			
			$sql = "INSERT INTO attachments (id,
							 container_id, 
							 container_type, 
							 filename,
							 filesize,
							 disk_filename,
							 content_type,
							 digest,
							 downloads,
							 author_id,
							 created_on,
							 description)
					VALUES (" . $attachment->id . ", 
						" . $attachment->container_id . ", 
						'" . mysql_real_escape_string($attachment->container_type) . "', 
						'" . mysql_real_escape_string($attachment->filename) . "', 
						" . $attachment->filesize . ",
						'" . mysql_real_escape_string($attachment->disk_filename) . "', 
						'" . mysql_real_escape_string($attachment->content_type) . "', 
						'" . mysql_real_escape_string($attachment->digest) . "', 
						'" . mysql_real_escape_string($attachment->downloads) . "', 
						'" . mysql_real_escape_string($attachment->author_id) . "', 
						'" . mysql_real_escape_string($attachment->created_on) . "', 
						'" . mysql_real_escape_string($attachment->description) . "')";
					
			$result = mysql_query($sql) or die(mysql_error().$sql);
		}
	}	

	// Create Redmine Journals from Bugzilla Comments
	echo "Emptying Journal tables.\n";

	$sql = "DELETE FROM journals";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	$sql = "DELETE FROM journal_details";
	$result = mysql_query($sql) or die(mysql_error().$sql);

	echo count($journals) . " Journal Entries to import.\n";
	foreach ($journals as $key=>$journal) {
		$continue = true;
		$sql = "SELECT * FROM journals WHERE id = " . $journal->id;

		$result = mysql_query($sql) or die(mysql_error().$sql);	
		if ($row = mysql_fetch_array($result)) $continue = false;

		if ($continue) {			
			$sql = "INSERT INTO journals (id, 
						      journalized_id, 
						      journalized_type, 
						      user_id,
						      notes,
						      created_on)
					VALUES (" . $journal->id . ", 
						" . $journal->journalized_id . ", 
						'" . mysql_real_escape_string($journal->journalized_type) . "', 
						" . $journal->user_id . ", 
						'" . mysql_real_escape_string($journal->notes) . "', 
						'" . mysql_real_escape_string($journal->created_on) . "')";
					
			$result = mysql_query($sql) or die(mysql_error().$sql);
		}
	}

?>
