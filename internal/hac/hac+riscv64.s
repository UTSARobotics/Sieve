.text

.global hac.count
.global haccount


.arch rv64gc

hac.count:
haccount:
	rdcycle      a0            /* Read cycle counter into a0 */
	ret
