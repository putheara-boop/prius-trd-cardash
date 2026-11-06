#import <Foundation/Foundation.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <mach/mach_time.h>
extern char **environ;
static double TRDMonotonic(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return (double)mach_absolute_time()*t.numer/t.denom/1e9;}
// Call on a worker queue. Capture is bounded; only the child created here is signalled.
static BOOL TRDRun(const char *path,char *const argv[],double timeout,NSString **output,BOOL *timedOut){
 int pipes[2];if(timedOut)*timedOut=NO;if(output)*output=@"Could not launch command";
 if(pipe(pipes))return NO;
 posix_spawn_file_actions_t actions;posix_spawn_file_actions_init(&actions);
 posix_spawn_file_actions_adddup2(&actions,pipes[1],STDOUT_FILENO);posix_spawn_file_actions_adddup2(&actions,pipes[1],STDERR_FILENO);
 posix_spawn_file_actions_addclose(&actions,pipes[0]);posix_spawn_file_actions_addclose(&actions,pipes[1]);
 pid_t child=0;int error=posix_spawn(&child,path,&actions,NULL,argv,environ);posix_spawn_file_actions_destroy(&actions);close(pipes[1]);
 if(error){close(pipes[0]);return NO;}
 fcntl(pipes[0],F_SETFL,fcntl(pipes[0],F_GETFL)|O_NONBLOCK);
 NSMutableData *data=[NSMutableData data];int status=0;BOOL done=NO,expired=NO;double deadline=TRDMonotonic()+timeout;
 while(YES){char buffer[1024];ssize_t count;int reads=0;
  while(reads++<16&&(count=read(pipes[0],buffer,sizeof(buffer)))>0){NSUInteger take=MIN((NSUInteger)count,8192-data.length);if(take)[data appendBytes:buffer length:take];}
  if(!done){pid_t result=waitpid(child,&status,WNOHANG);if(result==child)done=YES;else if(result<0&&errno!=EINTR){done=YES;status=-1;}}
  if(done)break;
  if(TRDMonotonic()>=deadline){expired=YES;kill(child,SIGKILL);while(waitpid(child,&status,0)<0&&errno==EINTR){}break;}
  usleep(20000);
 }
 close(pipes[0]);if(timedOut)*timedOut=expired;
 if(output)*output=expired?@"Command timed out":([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]?:@"Invalid command response");
 return !expired&&status!=-1&&WIFEXITED(status)&&WEXITSTATUS(status)==0;
}
