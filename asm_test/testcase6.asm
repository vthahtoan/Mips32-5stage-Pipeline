# 1. TEST DATA HAZARD
addi $1, $0, 5       # $1 = 5
add  $2, $1, $1      # EXPECTED: $2 = 10
add  $3, $2, $1      # EXPECTED: $3 = 15
add  $4, $3, $1	     # EXPECTED: $4 = 20
# 2. TEST L?NH JUMP (j)
j    jump_pass       # Nh?y qua 3 l?nh d??i
addi $4, $0, 999     # EXPECTED: ko ch?y
addi $4, $0, 999     # EXPECTED: ko ch?y
addi $4, $0, 999     # EXPECTED: ko ch?y
jump_pass:
# N?u nh?y ?úng thì s? ch?y dòng này
addi $5, $3, 5       # EXPECTED: $5 = 20 (15 + 5)
