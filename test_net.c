#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>
#include <sys/select.h>

int test_conn(const char *ip, int port, int timeout_sec) {
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) return -1;
    int flags = fcntl(s, F_GETFL, 0);
    fcntl(s, F_SETFL, flags | O_NONBLOCK);

    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_port = htons(port);
    inet_pton(AF_INET, ip, &sin.sin_addr);

    int r = connect(s, (struct sockaddr *)&sin, sizeof(sin));
    if (r < 0 && errno != EINPROGRESS) {
        close(s);
        return -2;
    }

    fd_set wset;
    FD_ZERO(&wset);
    FD_SET(s, &wset);
    struct timeval tv = { .tv_sec = timeout_sec, .tv_usec = 0 };

    int sel = select(s + 1, NULL, &wset, NULL, &tv);
    if (sel > 0) {
        int err = 0;
        socklen_t len = sizeof(err);
        getsockopt(s, SOL_SOCKET, SO_ERROR, &err, &len);
        close(s);
        return (err == 0) ? 0 : err;
    }
    close(s);
    return -3; // timeout
}

int main() {
    printf("--- Non-blocking Network Test ---\n");
    
    // 1. Gateway
    int g = test_conn("10.238.94.64", 53, 1);
    printf("Gateway 10.238.94.64:53 -> %s (%d)\n", g == 0 ? "SUCCESS" : "FAIL", g);

    // 2. Direct Internet IP (1.1.1.1:80)
    int c = test_conn("1.1.1.1", 80, 2);
    printf("Internet 1.1.1.1:80     -> %s (%d)\n", c == 0 ? "SUCCESS" : "FAIL", c);

    // 3. Direct Internet IP (8.8.8.8:53)
    int d = test_conn("8.8.8.8", 53, 2);
    printf("DNS 8.8.8.8:53          -> %s (%d)\n", d == 0 ? "SUCCESS" : "FAIL", d);

    // 4. DNS resolution
    printf("Resolving captive.apple.com...\n");
    struct hostent *he = gethostbyname("captive.apple.com");
    if (he) {
        char *ip = inet_ntoa(*(struct in_addr *)he->h_addr);
        printf("Resolved captive.apple.com -> %s\n", ip);
    } else {
        printf("Failed to resolve captive.apple.com (h_errno %d)\n", h_errno);
    }

    return 0;
}
