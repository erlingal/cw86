#define _GNU_SOURCE

#include <time.h>
#include <string.h>
#include <sys/resource.h>
#include <err.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/random.h>
#include <sys/wait.h>
#include <unistd.h>

int verb;

uint64_t big_rand() {
  uint64_t u;
  if (getrandom(&u, sizeof(u), GRND_NONBLOCK) != sizeof(u)) {
    err(1, "rand");
  }
  return u;
}

typedef struct {
  const char *name;
  uint32_t addr;
  int pid;
  int score;
} player;

void stopped(player *p, int score, int status) {
  if (p->pid) {
    const char *signame = sigdescr_np(status & 127);
    if (verb)
      printf("%d points: %s (%s)\n", score, p->name, status == 0 ? "Survived" : signame ? signame : "-");
    else
      printf("%s=%d ", p->name, score);
    p->pid = 0;
  }
}

void kill_it(int x, void *v) {
  player *p = (player*) v;
  if (p->pid) kill(p->pid, SIGKILL);
}

int main(int argc, char **argv) {
  verb = !getenv("SHORT");
 
  if (verb) {
    printf("...");
    fflush(stdout);
  }

  struct rlimit lim = {
    0, 0
  };
  setrlimit(RLIMIT_CORE, &lim);
  
  int corefd = memfd_create("core", 0);
  if (corefd < 0) err(1, "memfd_create");
  if (ftruncate(corefd, 0x100001000ull)) err(1,"ftruncate");
  dup2(corefd, 42);

  if (MAP_BASE != (uint64_t) mmap((void*) MAP_BASE, 4096, PROT_READ, MAP_PRIVATE | MAP_FIXED | MAP_ANONYMOUS, 0, 0)) {
    errx(1, "Can't map zero page. Try: sudo sysctl -w vm.mmap_min_addr=0");
  }

  char *space = mmap(0, MAP_SIZE, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED | MAP_POPULATE, corefd, 0);
  
  if (space == (char*) -1)
    err(1, "mmap");
  
  volatile uint64_t *bootargs = (volatile uint64_t*) space;

  int np = argc - 1;

  bootargs[0] = big_rand();
  bootargs[1] = 0;
  
  player *ply = calloc(np, sizeof(player));

  if (verb) printf("\r   \n");
   
  for (int i=0; i<np; i++) {
    ply[i].name = argv[i+1];
    
    int fd = open(ply[i].name, O_RDONLY);
    if (fd < 0) err(1, "can't open %s", ply[i].name);

    uint64_t addr = MAP_BASE + (big_rand() % MAP_SIZE);

    if (getenv("NORAND") && i < 2) {
      addr = i ? 0x10000000 : 0x90000000u;
    }

    int size = read(fd, space + addr - MAP_BASE, 65536);
    if (size < 0) err(1, "can't read %s", ply[i].name);
    close(fd);

    int pid = getenv("DEBUG_LAUNCH") ? 0 : fork();
    if (pid < 0) err(1, "fork");
    
    if (pid == 0) {
      char buf[20];
      sprintf(buf, "%lu", addr);
      char *argv[] = { buf, 0 };

      if (!getenv("FD")) {
        for (int i = 42; i --> 0; ) close(i);
      }
      
      execve("./boot.elf", argv, 0);
      
      exit(1);
    }
    ply[i].addr = addr;
    ply[i].pid = pid;
    on_exit(kill_it, &ply[i]);
    if (verb) printf("%5d bytes @ 0x%08x (pid %d) %s\n", size, ply[i].addr, ply[i].pid, ply[i].name);
  }

  time_t a = time(0);
  while (bootargs[1] < np) {
    if (time(0) > a + 1) {
      errx(1, "Loader failed to check in (%d/%d)", (int) bootargs[1], np);
    }
  }

  int tie = -1;
  
  if (getenv("DEBUG")) {
    printf("Not launching. Skip an instruction to start.\n");
  } else {
           
    tie = fork();
    if (tie < 0) err(1, "fork");
    if (tie == 0) {
      sleep(getenv("DEBUG") ? 600 : MAX_TIME);
      _exit(0);
    }
    
    bootargs[1] = 0;
    bootargs[0] = 0;
  }
  
  
  int score = 0;
  int stopat = getenv("DUEL") ? np - 1 : np;
  if (verb) printf("\n");
  while (score < stopat) {
    int status;
    int pid = wait(&status);
    if (pid <= 0) break;
    
    if (pid == tie) {
      score++;
      tie = 0;
      break;
    } else {
      for (int i=0; i<np; i++) {
        if (pid == ply[i].pid) {
          stopped(&ply[i], score, status);
        }
      }
      score++;
    }
  }

  for (int i=0; i<np; i++) stopped(&ply[i], score, 0);

  printf("\n");
  if (tie) kill(tie, SIGKILL);
}
