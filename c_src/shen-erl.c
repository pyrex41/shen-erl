#include <stdio.h> /* printf */
#include <stdlib.h> /* malloc, free */
#include <string.h> /* strlen, strrchr */
#include <unistd.h> /* execvp */
#include <stdarg.h> /* va_list, va_start, va_end */
#include <errno.h> /* errno */

#define PUSH(s) Eargv[Eargc++] = s
#define PROGNAME "erl"

/* Local functions */
static void error(char *format, ...);
static int resolve_executable(const char *argv0, char *resolved);

int main(int argc, char **argv)
{
  char **Eargv = NULL;
  int Eargc = 0;
  char* rootdir;
  char* path;
  char resolved[4096];
  int i = 1;

  rootdir = getenv("SHEN_ERL_ROOTDIR");

  if (rootdir == NULL) {
    char *bin;
    if (!resolve_executable(argv[0], resolved)) {
      error("cannot resolve launcher path '%s'", argv[0]);
    }
    bin = strrchr(resolved, '/');
    if (bin == NULL) {
      error("cannot determine installation root from '%s'", resolved);
    }
    *bin = '\0';
    bin = strrchr(resolved, '/');
    if (bin == NULL) {
      error("cannot determine installation root from '%s'", resolved);
    }
    *bin = '\0';
    rootdir = resolved;
  }
  path = malloc(strlen(rootdir) + 6);
  sprintf(path, "%s/ebin", rootdir);

  Eargv = (char **)malloc(sizeof(*argv) * (argc + 16));
  Eargc = 0;
  PUSH(PROGNAME);			/* The program we are going to run */

  PUSH("-pa");
  PUSH(path);

  PUSH("-noshell");

  /* Running shen_erl_init */
  PUSH("-s");
  PUSH("shen_erl_init");

  PUSH("+P");
  PUSH("524288");

  /* Typechecking uses eval-kl heavily; each generated BEAM module consumes an
     atom.  The stock one-million limit is below the canonical suite's needs. */
  PUSH("+t");
  PUSH("4194304");

  PUSH("-extra"); /* Program arguments */

  /* Add the rest to the stack and terminate it. */
  while (i < argc) {
    PUSH(argv[i++]);
  }

  Eargv[Eargc] = NULL;

  execvp(PROGNAME, Eargv);

  error("Error %d executing '%s'", errno, PROGNAME);
}

static int resolve_executable(const char *argv0, char *resolved)
{
  char *path_env;
  char *search_path;
  char *directory;

  if (strchr(argv0, '/') != NULL) {
    return realpath(argv0, resolved) != NULL;
  }

  path_env = getenv("PATH");
  if (path_env == NULL) {
    return 0;
  }

  search_path = malloc(strlen(path_env) + 1);
  if (search_path == NULL) {
    error("out of memory while resolving launcher path");
  }
  memcpy(search_path, path_env, strlen(path_env) + 1);

  directory = strtok(search_path, ":");
  while (directory != NULL) {
    char candidate[4096];
    int length = snprintf(candidate, sizeof(candidate), "%s/%s", directory, argv0);
    if (length > 0 && (size_t)length < sizeof(candidate) &&
        access(candidate, X_OK) == 0 && realpath(candidate, resolved) != NULL) {
      free(search_path);
      return 1;
    }
    directory = strtok(NULL, ":");
  }

  free(search_path);
  return 0;
}

static void error(char* format, ...)
{
  char sbuf[1024];
  va_list ap;

  va_start(ap, format);
  vsnprintf(sbuf, sizeof(sbuf), format, ap);
  va_end(ap);
  fprintf(stderr, "shen-erl: %s\n", sbuf);
  exit(1);
}
