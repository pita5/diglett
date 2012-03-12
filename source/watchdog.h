#import <Foundation/Foundation.h>

static const char* watchd_get_path() {
    // Application Support / Chocolat / diglett-watchd
    NSString *watchdfile = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Chocolat/diglett-watchd"];
    
    return [watchdfile fileSystemRepresentation];
}
static void watchd_client_refresh_file() {
    FILE* f = fopen(watchd_get_path(), "w");
    fputc('k', f);
    fclose(f);
}

static dispatch_source_t timersource;

#ifdef DIGLETT_SERVER
static BOOL watchd_diglett_veto;
static void watchd_handle_hang() {
    // Kill diglett
    if ([taskit isRunning]) {
        [taskit kill];
    }
    
    dispatch_suspend(timersource);
    
    // Make sure it never comes back
    watchd_diglett_veto = YES;
}
static void watchd_server_check_file() {
    if (![taskit isRunning])
        return;
    
    // Check the file. Does it contain "not-ok"?
    FILE* f = fopen(watchd_get_path(), "r+");
    int c = fgetc(f);
    if (c == 'n') {
        
        // oh dear
        watchd_handle_hang();
    }
    else {
        rewind(f);
        fputc('n', f);
    }
    fclose(f);
}
#endif

static void watchd_poll(int interval, void(*callback)(void)) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        timersource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timersource,
                                  DISPATCH_TIME_NOW,
                                  interval * NSEC_PER_SEC,
                                  1 * NSEC_PER_SEC);
        
        dispatch_source_set_event_handler(timersource, ^{
            callback();
        });
        dispatch_resume(timersource);
    });
}