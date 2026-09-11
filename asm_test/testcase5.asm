# 1. Kh?i t?o 
addi $1, $0, 25      # $1 = 25
andi $2, $1, 15      # EXPECTED: $2 = 9   (25 & 15 = 9)
ori  $3, $2, 16      # EXPECTED: $3 = 25  (9 | 16 = 25)
# 2. Ghi vào b? nh? (sw)
sw   $3, 0($0)       # L?u s? 25 ($3) vào ??a ch? RAM[0]
# 3. ??c t? b? nh? (lw)
lw   $4, 0($0)       # ??c RAM[0] vào $4 (Data = 25)
add  $5, $4, $2      # EXPECTED: $5 = 34 -> M?ch s? stall 1 nh?p
# 4. Test ??a ch? RAM khác
li   $6, -10         # EXPECTED: $6 = -10
sw   $6, 4($0)       # L?u s? -10 ($6) vào ??a ch? RAM[4]
lw   $7, 4($0)       # EXPECTED: $7 = -10
