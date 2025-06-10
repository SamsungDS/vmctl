#include "limits.h"
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))

#define VMCTL_INIT_VERBOSITY 0
#if VMCTL_INIT_VERBOSITY
#include <stdio.h>
#include <stdarg.h>

char const *const indent_str = "    ";
static void info(unsigned indent, char const *fmt, ...)
{
	while (0 != indent--)
		fprintf(stdout, "%s", indent_str);

	va_list args;
	va_start(args, fmt);
	vfprintf(stdout, fmt, args);
	va_end(args);

	fprintf(stdout, "\n");
}
static void prnt_args(int argc, char *argv[])
{
	info(1, "VMCTL image-less INIT started ... \n");
	info(1, "Arguments :\n");
	info(2, "argc = %d\n", argc);
	info(2, "argv:\n");
	for (int i = 0; i < argc; i++)
		info(3, "argv[%d] = %s\n", i, argv[i]);
}

#else
static inline void info(unsigned indent, char const *fmt, ...)
{
}
static inline void prnt_args(int argc, char *argv[])
{
}
#endif

struct ArgOpt{
	const char *arg_str;
	char ***arg_vals;
	int *count;
};

// Parse function to match arguments and store their values
void parse_args(int argc, char *argv[], struct ArgOpt *options, int option_count) {
	for (int i = 1; i < argc; i++) {
		for (int j = 0; j < option_count; j++) {
			if (strcmp(argv[i], options[j].arg_str) == 0 && i + 1 < argc) {
				(*options[j].count)++;
				*options[j].arg_vals =
					realloc(*options[j].arg_vals,
						(*options[j].count) * sizeof(char *));
				(*options[j].arg_vals)[(*options[j].count) - 1] = argv[i + 1];
				i++;
				break;
			}
		}
	}
}

int ensure_dir(char *path)
{
	if (path[0] == '\0')
		return -1;

	for(int idx = 1, path_end =0; idx < PATH_MAX; ++idx) {
		if (path[idx] != '/' && path[idx] != '\0')
			continue;

		if (path[idx] == '\0')
			path_end = 1;
		else
			path[idx] = '\0';

		if (mkdir(path, 0755) == -1 && errno != EEXIST)
			goto err;

		if (path_end)
			return 0;
		else
			path[idx] = '/';
	}

err:
	info(1, "Error: creating the path (%s)", path);
	return -1;

}

int read_until(const char *str, char c)
{
	int idx;
	for(idx = 0 ; str[idx] != '\0' && str[idx] != c; ++idx)
		;
	return idx;
}

/* mount_str: mount str (SHARE_NAME;MOUNT_PATH;MOUNT_TYPE) */
int mount_from_str(char *mount_str)
{
	int idx, i = 0, end = 0;
	char *strs[3] = {mount_str, NULL, NULL};

	info(1, "Mount string: %s", mount_str);
	do {
		idx = read_until(strs[i], ',');
		if (idx == 0)
			break;

		if(strs[i][idx] == '\0')
			end = 1;
		else {
			strs[i][idx] = '\0';
			strs[i+1] = strs[i] + idx + 1;
		}

		if (end)
			break;

		i++;
	} while (i < 3);

	if (strs[1] == NULL || strs[2] == NULL)
		return -1;

	if (ensure_dir(strs[1]))
		return -1;

	if (mount(strs[0], strs[1], strs[2], 0, "") == -1) {
		info(1, "Error: mounting %s at %s. errno %d",
		     strs[0], strs[1], errno);
		return 1;
	}

	info(1, "Mounted %s at %s\n", strs[0], strs[1]);

	return 0;
}

int main(int argc, char *argv[])
{
	int ret;
	char **mount_strs = NULL, **init_paths = NULL;
	int mounts_count = 0, init_paths_count = 0;
	struct ArgOpt opts[] = {
		{"--init-path", &init_paths, &init_paths_count},
		{"--mount", &mount_strs, &mounts_count},
	};

	prnt_args(argc, argv);
	parse_args(argc, argv, opts, ARRAY_SIZE(opts));
	if (init_paths_count != 1) {
		info(1, "Error: %s --init-path arg",
		     init_paths_count == 0 ? "missing" : "too many");
		return -1;
	}

	for (int i = 0; i < mounts_count; ++i) {
		if (mount_from_str(mount_strs[i])) {
			info(1, "Error: Could not mount");
			return -1;
		}
	}

	info(1, "Attempting to exec: %s\n", init_paths[0]);
	execv(init_paths[0], argv);
	info(1, "Error: execv failed");

	return -1;
}
