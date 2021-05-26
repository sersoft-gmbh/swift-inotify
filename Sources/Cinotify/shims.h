#ifndef CINOTIFY_SHIMS_H
#define CINOTIFY_SHIMS_H

#include <stdint.h>
#include <sys/inotify.h>

typedef struct inotify_event cinotify_event;

static inline const char* cin_event_name(cinotify_event event) {
	if (event.len)
		return event.name;
	else
		return '\0';
}

static const uint32_t cin_all_events = IN_ALL_EVENTS;

#endif /* CINOTIFY_SHIMS_H */
