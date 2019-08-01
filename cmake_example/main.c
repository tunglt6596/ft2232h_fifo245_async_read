#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <ftdi.h>
#include <time.h>

#define WIDTH 128
#define BURST_LEN 128

struct element {
    unsigned int address;
    char data[WIDTH/8];
};

static void write_memory(struct ftdi_context *ftdi,
                         const char *filename,
                         unsigned int address)
{
    FILE *f = fopen(filename, "r");
    // Send packets to the FPGA
    struct element elems[BURST_LEN];
    unsigned int i = 0;

    while (!feof(f)) {
        // Produce element
        elems[i].address = address | 0x80000000;    // Set "write" flag
        fread(&elems[i].data, WIDTH/8, 1, f);
        // If the list of elements is full, send them
        if (i == BURST_LEN - 1) {
            ftdi_write_data(ftdi, (unsigned char *)&elems, sizeof(elems));

            i = 0;
        } else {
            ++i;
        }
        // Prepare for next address
        address += WIDTH / 8;
    }

    // Write last elements
    if (i != 0) {
        ftdi_write_data(ftdi, (unsigned char *)&elems, i * sizeof(struct element));
    }

    printf("    done\n");
    fclose(f);
}

static void read_memory(struct ftdi_context *ftdi,
                        const char *filename,
                        unsigned char address,
                        unsigned int size)
{
    fprintf(stderr, "Read_1\n");
    struct ftdi_transfer_control *wr_transfer, *rd_transfer;
    FILE *f = fopen(filename, "w");

    printf("Reading file %s from address 0x%08x...\n", filename, address);
    
    // Send packets to the FPGA
    unsigned char addresses[BURST_LEN];
    char buf[BURST_LEN * WIDTH/8];
    unsigned int i = 0;
    
    wr_transfer = ftdi_write_data_submit(ftdi, (unsigned char *)&addresses, sizeof(addresses));
    ftdi_transfer_data_done(wr_transfer);
    
    ftdi_usb_purge_rx_buffer(ftdi);
    
    for (int j=0; j<size; j += WIDTH/8) {
        if (i == BURST_LEN - 1) {
            // Read data
            rd_transfer = ftdi_read_data_submit(ftdi, (unsigned char *)&buf, sizeof(buf));
            // Wait for transfers to complete and write data to file
            if (rd_transfer) {
                ftdi_transfer_data_done(rd_transfer);
                fwrite(&buf, sizeof(buf), 1, f);
            }
            i = 0;
        } else {
            ++i;
        }
    }
    
    // Process last elements
    if (i != 0) {
        rd_transfer = ftdi_read_data_submit(ftdi, (unsigned char *)&buf, i * WIDTH/8);
        if (rd_transfer) {
            ftdi_transfer_data_done(rd_transfer);
            fwrite(&buf, i * WIDTH/8, 1, f);
        }
    }
    
    printf("    done\n");
    fclose(f);
}

int main(int argc, char **argv)
{
    int ret;
    struct ftdi_context *ftdi;
    struct ftdi_version_info version;
    clock_t start, end;
    double cpu_time_used;
    
    if ((ftdi = ftdi_new()) == 0)
    {
        fprintf(stderr, "ftdi_new failed\n");
        return EXIT_FAILURE;
    }

	if (ftdi_set_interface(ftdi, INTERFACE_B) < 0)
   	{
       fprintf(stderr, "ftdi_set_interface failed\n");
       ftdi_free(ftdi);
       return EXIT_FAILURE;
	}

    if ((ret = ftdi_usb_open(ftdi, 0x0403, 0x6010)) < 0)
    {
        fprintf(stderr, "unable to open ftdi device: %d (%s)\n", ret, ftdi_get_error_string(ftdi));
        ftdi_free(ftdi);
        return EXIT_FAILURE;
    }

    // Parse EEPROM values
    if (ftdi_read_eeprom(ftdi) == 0) {
        ftdi_eeprom_decode(ftdi, 1);
    }

    // // Set channel A mode to Synchronous FIFO
    // if (ftdi_set_bitmode(ftdi, 0xFF, BITMODE_SYNCFF) != 0) {
    //     fprintf(stderr, "Failed to set Channel A mode to Synchronous FIFO");
    //     ftdi_free(ftdi);
    //     return EXIT_FAILURE;
    // }

    // Perform user action
    if (argc < 4) {
        fprintf(stderr, "Usage: %s <r|w> <filename> <address>\n", argv[0]);
        ftdi_free(ftdi);
        return EXIT_FAILURE;
    }

    ftdi_usb_purge_rx_buffer(ftdi);
    ftdi_usb_purge_tx_buffer(ftdi);
    
    if (argv[1][0] == 'r') {
        // Read
        fprintf(stderr, "Read\n");
        start = clock();
        read_memory(ftdi, argv[2], strtol(argv[3], NULL, 0), strtol(argv[4], NULL, 0));
        end = clock();
        cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
        printf("Reading time: %f\n", cpu_time_used);
    } else {
        // Write
        fprintf(stderr, "Write\n");
        write_memory(ftdi, argv[2], strtol(argv[3], NULL, 0));
    }

    ftdi_free(ftdi);
    return EXIT_SUCCESS;
}
