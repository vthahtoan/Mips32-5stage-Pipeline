# N?p d? li?u
addi $1, $0, 10    # $1 = 10
addi $2, $0, 3     # $2 = 3
# Test các l?nh R-Type
add  $3,  $1, $2   # EXPECTED: $3 = 13
sub  $4,  $1, $2   # EXPECTED: $4 = 7
and  $5,  $1, $2   # EXPECTED: $5 = 2
or   $6,  $1, $2   # EXPECTED: $6 = 11
xor  $7,  $1, $2   # EXPECTED: $7 = 9
nor  $8,  $1, $2   # EXPECTED: $8 = -12
slt  $9,  $2, $1   # EXPECTED: $9 = 1
sll  $10, $2, 2    # EXPECTED: $10 = 12
srl  $11, $1, 1    # EXPECTED: $11 = 5