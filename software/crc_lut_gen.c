#include <stdio.h>
#include <stdint.h>

#define POLY 0x04C11DB7  
#define TABLE_SIZE  256

/* Generate remainders for LUT0 */
void generate_table0(uint32_t table[TABLE_SIZE]) {

    for (uint32_t i_byte = 0; i_byte < TABLE_SIZE; i_byte++) {  
        uint32_t crc_byte = 0;

        crc_byte = (i_byte << 24) ^ crc_byte;

        // Perform modulo-2 arithmetic for each bit
        for (uint8_t i = 0; i < 8; i++) {
            
            if ((crc_byte & 0x80000000) != 0)
                crc_byte = (crc_byte << 1) ^ POLY;
            else
                crc_byte <<= 1;
        }
        
        table[i_byte] = crc_byte;
    }
}

// Generate tables 1 through 3
void generate_tables(uint32_t table0[TABLE_SIZE],
                     uint32_t table1[TABLE_SIZE],
                     uint32_t table2[TABLE_SIZE],
                     uint32_t table3[TABLE_SIZE]) {
    for (int i = 0; i < TABLE_SIZE; i++) {
        uint32_t c;

        // Advance 1 byte
        c = table0[i];
        table1[i] = (c << 8) ^ table0[(c >> 24) & 0xFF];

        // Advance 2 bytes
        c = table1[i];
        table2[i] = (c << 8) ^ table0[(c >> 24) & 0xFF];

        // Advance 3 bytes
        c = table2[i];
        table3[i] = (c << 8) ^ table0[(c >> 24) & 0xFF];
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


