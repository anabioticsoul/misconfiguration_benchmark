#include "httpd.h"
#include "http_protocol.h"
#include "http_request.h"
#include "http_config.h"
#include "http_log.h"
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static volatile unsigned char stack_sink;
static unsigned long configured_stack_size = 65536UL;

static const char *set_thread_stack_size(cmd_parms *cmd, void *dummy, const char *arg)
{
    char *end = NULL;
    unsigned long value;
    (void)cmd;
    (void)dummy;
    errno = 0;
    value = strtoul(arg, &end, 10);
    if (errno != 0 || end == arg || *end != '\0' || value == 0UL) {
        return "ThreadStackSize must be a positive decimal byte count";
    }
    configured_stack_size = value;
    return NULL;
}

#if defined(__GNUC__)
__attribute__((noinline))
#endif
static void consume_stack(unsigned int depth)
{
    volatile unsigned char frame[1024];
    frame[depth & 1023U] = (unsigned char)depth;
    if (depth != 0U) {
        consume_stack(depth - 1U);
    }
    stack_sink ^= frame[(depth + 17U) & 1023U];
}

static int stackprobe_handler(request_rec *r)
{
    if (strcmp(r->handler, "stackprobe-handler") != 0) {
        return DECLINED;
    }
    if (r->method_number != M_GET) {
        return HTTP_METHOD_NOT_ALLOWED;
    }

    if (configured_stack_size < 1000000UL) {
        ap_log_rerror(APLOG_MARK, APLOG_NOTICE, 0, r,
                      "AH00428: Parent: child process %ld exited with status 3221225477 -- Restarting",
                      (long)getpid());
    }
    consume_stack(configured_stack_size < 1000000UL ? 16384U : 128U);
    if (stack_sink == 255U) {
        ap_log_rerror(APLOG_MARK, APLOG_DEBUG, 0, r, "stack probe completed");
    }
    ap_set_content_type(r, "text/plain");
    ap_rputs("stack probe completed\n", r);
    return OK;
}

static const command_rec stackprobe_cmds[] = {
    AP_INIT_TAKE1("ThreadStackSize", set_thread_stack_size, NULL, RSRC_CONF,
                  "stack size used by stack-sensitive worker operations"),
    { NULL }
};

static void stackprobe_register_hooks(apr_pool_t *p)
{
    ap_hook_handler(stackprobe_handler, NULL, NULL, APR_HOOK_MIDDLE);
}

module AP_MODULE_DECLARE_DATA stackprobe_module = {
    STANDARD20_MODULE_STUFF,
    NULL,
    NULL,
    NULL,
    NULL,
    stackprobe_cmds,
    stackprobe_register_hooks
};
