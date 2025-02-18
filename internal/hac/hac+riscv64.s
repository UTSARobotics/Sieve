.text

.global hac.count
.global haccount


.arch rv64gc

hac.count:
	rdcycle      a0            /* Read cycle counter into a0 */
	ret
