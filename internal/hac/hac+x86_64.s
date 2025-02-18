.text

.global hac.count
.global haccount

/* x86_64 version */

hac.count:
	/* RDTSC loads upper 32 bits into RDX and lower into RAX */
	/* lfence                  /* (DISABLED) Prevent execution reordering */
	xorq %rax, %rax
	rdtsc                      /* Read time stamp counter */
	shl $32, %rdx          /* Shift upper 32 bits */
	orq %rdx, %rax         /* Combine into 64-bit value in RAX */
	ret
