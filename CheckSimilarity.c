#include <stdio.h>

int main(void)
{
    FILE *fi1 = NULL, *fi2 = NULL;
     
    if ( (fi1 = fopen("test1.bin", "rb")) == NULL) {
        printf("File 1 not found\n");
        return -1;
    }
    if ( (fi2 = fopen("test2.bin", "rb")) == NULL) {
        printf("File 2 not found\n");
        return -1;
    }
    
    int x, y;
    int i = 0;
    
    while(!feof(fi1))
    {
        x = fread(&x, sizeof(int), 1, fi1);
        y = fread(&y, sizeof(int), 1, fi2);
        if (x != y) {
            printf("Difference appeared at line %d, x = %d while y = %d\n", (i>>2)+1, x, y);
            return -1;
        }
        i += 1;
    }
    
    printf("Comparing has finished!!!\n");
    return 0;
}
