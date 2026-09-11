# --- SETUP BAN ??U ---
addi $t1, $zero, 10    # EXPECTED: $t1 = 10
addi $t2, $zero, 20    # EXPECTED: $t2 = 20

# ---------------------------------------------------------
# 1. KHO?NG CÁCH 1 (EX-to-EX Forwarding)
# ---------------------------------------------------------
add  $t3, $t1, $t2     # EXPECTED: $t3 = 30
sub  $t4, $t3, $t1     # EXPECTED: $t4 = 20 (Forward $t3 t? MEM)

# ---------------------------------------------------------
# 2. KHO?NG CÁCH 2 (MEM-to-EX Forwarding)
# ---------------------------------------------------------
add  $t5, $t3, $t4     # EXPECTED: $t5 = 50
addi $t7, $zero, 100   # EXPECTED: $t7 = 100 (L?nh chèn 1)
and  $t6, $t5, $t1     # EXPECTED: $t6 = 2   (50 & 10 = 2, Forward $t5 t? WB)

# ---------------------------------------------------------
# 3. KHO?NG CÁCH 3 (X? lý n?i b? trong RegisterFile)
# ---------------------------------------------------------
add  $s0, $t1, $t1     # EXPECTED: $s0 = 20
sub  $t8, $t2, $t1     # EXPECTED: $t8 = 10  (L?nh chèn 2)
add  $t9, $t7, $t8     # EXPECTED: $t9 = 110 (L?nh chèn 3)
or   $s1, $s0, $t2     # EXPECTED: $s1 = 20  (20 | 20 = 20, ??c $s0 tr?c ti?p t? RegFile)

# ---------------------------------------------------------
# 4. LOAD-USE HAZARD (Hazard Unit phát hi?n Stall)
# ---------------------------------------------------------
addi $t9, $zero, 99    # EXPECTED: $t9 = 99 (T?o s? 99)
sw   $t9, 0($zero)     # L?U VÀO RAM: C?t s? 99 vào ??a ch? 0x0000
lw   $s2, 0($zero)     # EXPECTED: $s2 = 99
add  $s3, $s2, $t1     # EXPECTED: $s3 = 109 (B? Stall 1 nh?p, Forward $s2 t? WB)
