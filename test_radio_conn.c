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

int test_host_port(const char *host, int port) {
    struct hostent *he = gethostbyname(host);
    if (!he) {
        printf("%-20s -> DNS FAILED (h_errno %d)\n", host, h_errno);
        return -1;
    }
    char *ip = inet_ntoa(*(struct in_addr *)he->h_addr);
    
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) return -2;
    int flags = fcntl(s, F_GETFL, 0);
    fcntl(s, F_SETFL, flags | O_NONBLOCK);

    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_port = htons(port);
    sin.sin_addr = *(struct in_addr *)he->h_addr;

    int r = connect(s, (struct sockaddr *)&sin, sizeof(sin));
    if (r < 0 && errno != EINPROGRESS) {
        printf("%-20s -> CONNECT IMMEDIATE FAIL (errno %d)\n", host, errno);
        close(s);
        return -3;
    }

    fd_set wset;
    FD_ZERO(&wset);
    FD_SET(s, &wset);
    struct timeval tv = { .tv_sec = 3, .tv_usec = 0 };

    int sel = select(s + 1, NULL, &wset, NULL, &tv);
    if (sel > 0) {
        int err = 0;
        socklen_t len = sizeof(err);
        getsockopt(s, SOL_SOCKET, SO_ERROR, &err, &len);
        close(s);
        if (err == 0) {
            printf("%-20s (%s:%d) -> CONNECTED OK!\n", host, ip, port);
            return 0;
        } else {
            printf("%-20s (%s:%d) -> SOCK ERROR %d (%s)\n", host, ip, port, err, strerror(err));
            return err;
        }
    }
    close(s);
    printf("%-20s (%s:%d) -> TIMEOUT\n", host, ip, port);
    return -4;
}

int main() {
    printf("--- Testing Radio Endpoints from iPad ---\n");
    test_host_port("sv4.hostpleng.com", 8184);
    test_host_port("103.246.19.203", 8004);
    test_host_port("www.fm91bkk.com", 8900);
    test_host_port("122.155.16.48", 8955);
    test_host_port("coolism-web.cdn.byteark.com", 443);
    test_host_port("play-fm1005.mcot.net", 443);
    test_host_port("atimehd.smartclick.co.th", 443);
    return 0;
}
