# N?p d? li?u
addi $1, $0, 10      # $1 = 10
# 1. BNE KHÔNG NH?Y (So sánh 10 v?i 10)
bne  $1, $1, error   # ko nh?y (vì b?ng nhau)
addi $2, $0, 11      # EXPECTED: $2 = 11
# 2. BEQ NH?Y (So sánh 10 v?i 10)
beq  $1, $1, pass    # nh?y (vì b?ng nhau)
addi $4, $0, 999     # EXPECTED: ko ch?y
addi $5, $0, 999     # EXPECTED: ko ch?y
error:
addi $4, $0, 999     # EXPECTED: ko ch?y
pass:
addi $3, $0, 22      # EXPECTED: $3 = 22
