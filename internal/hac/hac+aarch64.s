.text

.global hac.count
.global haccount


.arch armv8-a

hac.count:
haccount:
	MRS     x0, CNTVCT_EL0     /* Read virtual counter */
	RET
