#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>

#define WANIP "/etc/wanip"
#define BUFSIZE 1024

char wanip[32];
char adslpass[32];
pid_t pid;

void finish (const char *msg, int code)
{
  bzero(adslpass, sizeof adslpass);
  if (pid) {
    kill(pid, SIGKILL);
  }
  if (msg) {
    puts(msg);
  }
  exit(code);
}

void timeout (int sig)
{
  finish("TIMEOUT", 1);
}

void error (int sig)
{
  finish("ERROR", 1);
}

void intr (int sig)
{
  finish("INTR", 1);
}

int copyval (const char *src, char *dst, int len)
{
  int i;
  if (!src || !dst || len < 1)
    return 0;
  while (isspace(*src))
    src++;
  for (i = 0; i < len-1 && src[i] && !isspace(src[i]); i++)
    dst[i] = src[i];
  dst[i] = 0;
  return i+1;
}

const char *strbeg (const char *buf, const char *match, int beg)
{
  const char *s = strstr (buf, match);
  if (!s)
    return NULL;
  if (beg) {
    if (s != buf) {
      const char *p = s - 1;
      while (p != buf && (*p == ' ' || *p == '\t'))
        p--;
      if (p != buf && *p != '\n' && *p != '\r')
        return NULL;
    }
  }
  return s + strlen(match);
}

int main()
{
  FILE *pfile, *fw;
  char buf[BUFSIZE];
  int pin[2], pout[2];
  const char *s;
  int mode, itimeout;
  char adslip[32] = "192.168.1.1";
  char telnet[32] = "/usr/bin/telnet";
  char stimeout[16] = "3";
  signal(SIGCHLD, SIG_IGN);
  signal(SIGALRM, timeout);
  signal(SIGINT, intr);
  signal(SIGQUIT, intr);
  signal(SIGABRT, error);
  pfile = fopen(WANIP, "r");
  if (!pfile)
    error(0);
  while (fgets(buf, sizeof buf, pfile)) {
    if (NULL != (s = strbeg(buf, "IP", 1)))
      copyval (s, adslip, sizeof adslip);
    if (NULL != (s = strbeg(buf, "PASS", 1)))
      copyval (s, adslpass, sizeof adslpass);
    if (NULL != (s = strbeg(buf, "TELNET", 1)))
      copyval (s, adslpass, sizeof telnet);
    if (NULL != (s = strbeg(buf, "TIMEOUT", 1)))
      copyval (s, stimeout, sizeof stimeout);
  }
  fclose(pfile);
  if (!*adslpass)
    error(0);
  if (pipe(pin) || pipe(pout))
    error(0);
  pid = fork();
  if (pid < 0) {
    pid = 0;
    error(0);
  }
  if (!pid) {
    bzero (adslpass, sizeof adslpass);
    if (dup2(pout[0], 0) < 0 || dup2(pin[1], 2) < 0 || dup2(2, 1) < 0)
      error(0);
    char *args[] = { telnet, adslip, NULL };
    execv (telnet, args);
    /* not reached */
    error(0);
  }
  itimeout = atoi(stimeout);
  alarm(itimeout > 0 ? : 3);
  fw = fdopen(pout[1], "w");
  if (!fw)
    error(0);
  mode = 0;
  while(1) {
    fflush(fw);
    bzero (buf, sizeof buf);
    read (pin[0], buf, sizeof buf);
    buf[sizeof(buf)-1] = 0;
    if (!*buf)
      break;
    //fprintf (stderr, "buf=[%s]\n", buf);
    if (mode == 0 && strbeg (buf, "Connected to", 0)) {
       mode = 1;
    }
    if (mode == 1 && (strbeg (buf, "login:", 1)
		|| strbeg (buf, "BusyBox on (none) login:", 1))) {
       fprintf (fw, "root\n");
       mode = 2;
    }
    if (mode == 2 && strbeg (buf, "Password:", 1)) {
       fprintf (fw, "%s\n", adslpass);
       bzero (adslpass, sizeof adslpass);
       mode = 3;
    }
    if (mode == 3 && strbeg (buf, "#", 1)) {
       fprintf (fw, "ifconfig ppp0\n");
       mode = 4;
       continue;
    }
    if (mode == 4 && NULL != (s = strbeg (buf, "inet addr:", 0))) {
       copyval (s, wanip, sizeof wanip);
       //fprintf(stderr, "ip search=[%s]\n", wanip);
    }
    if (mode == 4 && strbeg (buf, "#", 1)) {
       fprintf (fw, "exit\n");
       mode = 5;
       //fprintf(stderr,"exiting\n");
    }
    if (mode == 5 && strbeg (buf, "closed by foreign host", 0)) {
       pid = 0;
       break;
    }
  }
  if (*wanip)
    finish (wanip, 0);
  else
    error(0);
  return 0;
}
