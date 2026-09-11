# N?p d? li?u
addi $1, $0, 10      # $1 = 10
addi $2, $0, 20      # $2 = 20

# 1. BEQ KHÔNG NH?Y
beq  $1, $2, error_trap   # ko nh?y
addi $3, $0, 11      # EXPECTED: $3 = 11

# 2. BNE NH?Y
bne  $1, $2, jump_1       # nh?y
addi $4, $0, 999     # EXPECTED: ko ch?y
addi $4, $0, 999     # EXPECTED: ko ch?y

jump_1:
addi $5, $0, 22      # EXPECTED: $5 = 22

# 3. BNE KHÔNG NH?Y
bne  $1, $1, error_trap   # ko nh?y
addi $6, $0, 33      # EXPECTED: $6 = 33

# 4. BEQ NH?Y
beq  $1, $1, jump_2       # nh?y
addi $4, $0, 999     # EXPECTED: ko ch?y
addi $4, $0, 999     # EXPECTED: ko ch?y

error_trap:
addi $4, $0, 999     # EXPECTED: ko ch?y
j    end_test        # nh?y

jump_2:
addi $7, $0, 44      # EXPECTED: $7 = 44

end_test:
addi $8, $0, 100     # EXPECTED: $8 = 100