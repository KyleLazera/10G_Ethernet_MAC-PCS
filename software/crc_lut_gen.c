#include <stdio.h>
#include <stdint.h>

#define POLY 0x04C11DB7  
#define TABLE_SIZE  256

/* Generate table 0 */
void generate_table0(uint32_t table[TABLE_SIZE]) {

    for (uint32_t i = 0; i < TABLE_SIZE; i++) {        
        // Shift up to be inline with MSB of dividend
        uint32_t crc = i << 24;
        for (int j = 0; j < 8; j++) {

            // Check if most sig bits are both 1
            if (crc & 0x80000000)
                crc = (crc << 1) ^ POLY;
            else
                crc <<= 1;
        }
        table[i] = crc;
    }
}

/* Derive table[j] from table[j-1] */
void generate_tables(uint32_t table0[TABLE_SIZE],
                     uint32_t table1[TABLE_SIZE],
                     uint32_t table2[TABLE_SIZE],
                     uint32_t table3[TABLE_SIZE]) {
    
    for (int i = 0; i < TABLE_SIZE; i++) {
        uint32_t c = table0[i];

        // Advance by one extra byte
        uint32_t t1 = (c << 8) ^ table0[(c >> 24) & 0xFF];
        table1[i] = t1;

        // Advance by two extra bytes
        uint32_t t2 = (t1 << 8) ^ table0[(t1 >> 24) & 0xFF];
        table2[i] = t2;

        // Advance by three extra bytes
        uint32_t t3 = (t2 << 8) ^ table0[(t2 >> 24) & 0xFF];
        table3[i] = t3;
    }
}

// Write one table to file
void write_table(const char *filename, uint32_t table[256]) {
    FILE *f = fopen(filename, "w");
    if (!f) {
        printf("Error opening %s\n", filename);
        return;
    }

    for (int i = 0; i < TABLE_SIZE; i++) {
        fprintf(f, "%08X\n", table[i]);
    }

    fclose(f);
}

int main() {
    uint32_t table0[TABLE_SIZE], table1[TABLE_SIZE], table2[TABLE_SIZE], table3[TABLE_SIZE];

    // Step 1: generate base table
    generate_table0(table0);

    // Step 2: derive table1 - table3
    generate_tables(table0, table1, table2, table3);

    // Step 3: write all to separate files
    write_table("table0.txt", table0);
    write_table("table1.txt", table1);
    write_table("table2.txt", table2);
    write_table("table3.txt", table3);

    return 0;
}


