// Copyright 2017 The Wuffs Authors.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// https://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or https://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.
//
// SPDX-License-Identifier: Apache-2.0 OR MIT

// ----------------

// This file contains a hand-written C implementation of the Adler32 hash
// function, based on the code generated by the Wuffs std/zlib implementation.
// Its purpose is to benchmark different compilers, or different versions of
// the same compiler family.
//
// For example, on a Debian Testing system as of November 2017:
//
// $ clang-5.0 -O3 adler32-standalone.c; ./a.out
//     2311 MiB/s, clang 5.0.0 (tags/RELEASE_500/rc2)
// $ gcc       -O3 adler32-standalone.c; ./a.out
//     3052 MiB/s, gcc 7.2.1 20171025
//
// which suggest that clang's code performs at about 76% the throughput of
// gcc's. This is filed as https://bugs.llvm.org/show_bug.cgi?id=35567

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>

#define BUFFER_SIZE (1024 * 1024)
#define ONE_MIBIBYTE (1024 * 1024)

// The order matters here. Clang also defines "__GNUC__".
#if defined(__clang__)
const char* g_cc = "clang";
const char* g_cc_version = __clang_version__;
#elif defined(__GNUC__)
const char* g_cc = "gcc";
const char* g_cc_version = __VERSION__;
#elif defined(_MSC_VER)
const char* g_cc = "cl";
const char* g_cc_version = "???";
#else
const char* g_cc = "cc";
const char* g_cc_version = "???";
#endif

struct {
  int remaining_argc;
  char** remaining_argv;

  bool no_check;
} g_flags = {0};

const char*  //
parse_flags(int argc, char** argv) {
  int c = (argc > 0) ? 1 : 0;  // Skip argv[0], the program name.
  for (; c < argc; c++) {
    char* arg = argv[c];
    if (*arg++ != '-') {
      break;
    }

    // A double-dash "--foo" is equivalent to a single-dash "-foo". As special
    // cases, a bare "-" is not a flag (some programs may interpret it as
    // stdin) and a bare "--" means to stop parsing flags.
    if (*arg == '\x00') {
      break;
    } else if (*arg == '-') {
      arg++;
      if (*arg == '\x00') {
        c++;
        break;
      }
    }

    if (!strcmp(arg, "no-check")) {
      g_flags.no_check = true;
      continue;
    }

    return "main: unrecognized flag argument";
  }

  g_flags.remaining_argc = argc - c;
  g_flags.remaining_argv = argv + c;
  return NULL;
}

static uint32_t  //
calculate_hash(uint8_t* x_ptr, size_t x_len) {
  uint32_t s1 = 1;
  uint32_t s2 = 0;

  while (x_len > 0) {
    uint8_t* prefix_ptr;
    size_t prefix_len;
    if (x_len > 5552) {
      prefix_ptr = x_ptr;
      prefix_len = 5552;
      x_ptr = x_ptr + 5552;
      x_len = x_len - 5552;
    } else {
      prefix_ptr = x_ptr;
      prefix_len = x_len;
      x_ptr = NULL;
      x_len = 0;
    }

    uint8_t* p = prefix_ptr;
    uint8_t* end0 = prefix_ptr + (prefix_len / 8) * 8;
    while (p < end0) {
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
    }
    uint8_t* end1 = prefix_ptr + prefix_len;
    while (p < end1) {
      s1 += ((uint32_t)(*p));
      s2 += s1;
      p++;
    }

    s1 %= 65521;
    s2 %= 65521;
  }
  return (s2 << 16) | s1;
}

uint8_t g_buffer[BUFFER_SIZE] = {0};

int  //
main(int argc, char** argv) {
  const char* err_msg = parse_flags(argc, argv);
  if (err_msg) {
    fprintf(stderr, "%s\n", err_msg);
    return 1;
  }

  struct timeval bench_start_tv;
  gettimeofday(&bench_start_tv, NULL);

  const int num_reps = 1000;

  // If changing BUFFER_SIZE, re-calculate this expected value with
  // https://play.golang.org/p/IU2T58P00C
  const uint32_t expected_hash_of_1mib_of_zeroes = 0x00f00001UL;

  int num_bad = 0;
  for (int i = 0; i < num_reps; i++) {
    uint32_t actual_hash = calculate_hash(g_buffer, BUFFER_SIZE);
    if (!g_flags.no_check && (actual_hash != expected_hash_of_1mib_of_zeroes)) {
      num_bad++;
    }
  }
  if (num_bad) {
    printf("num_bad: %d\n", num_bad);
    return 1;
  }

  struct timeval bench_finish_tv;
  gettimeofday(&bench_finish_tv, NULL);

  int64_t micros =
      (int64_t)(bench_finish_tv.tv_sec - bench_start_tv.tv_sec) * 1000000 +
      (int64_t)(bench_finish_tv.tv_usec - bench_start_tv.tv_usec);
  int64_t numer = ((int64_t)num_reps) * BUFFER_SIZE * 1000000;
  int64_t denom = micros * ONE_MIBIBYTE;
  int64_t mib_per_s = denom ? numer / denom : 0;

  printf("%8d MiB/s, %s %s\n", (int)mib_per_s, g_cc, g_cc_version);
  return 0;
}
