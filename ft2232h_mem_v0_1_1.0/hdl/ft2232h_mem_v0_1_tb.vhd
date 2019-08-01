library ieee;
use ieee.std_logic_1164.all;

entity ft2232h_mem_v0_1_tb is 
end ft2232h_mem_v0_1_tb;

architecture tb_arch of ft2232h_mem_v0_1_tb is
    constant T        : time     := 10 ns;
    
    signal prog_d     : std_logic_vector(7 downto 0);
    signal prog_rxen  : std_logic;
    signal prog_txen  : std_logic;
    signal prog_rdn   : std_logic;
    signal prog_wrn   : std_logic;
    signal prog_siwun : std_logic;
    
    m00_axi_aclk      : std_logic;
    m00_axi_aresetn   : std_logic;
begin 
    -- instantiate the design under test
    dut: entity work.ft2232h_mem_v0_1(arch_imp)
        port map(prog_d=>prog_d, prog_rxen=>prog_rxen, prog_txen=>prog_txen,
                 prog_rdn=>prog_rdn, prog_wrn=>prog_wrn, prog_siwun=>prog_siwun,
                 m00_axi_aclk=>m00_axi_aclk, m00_axi_aresetn=>m00_axi_aresetn);
    -- ******************************************
    -- clock
    -- ******************************************
    -- 10 ns clock running forever
    process
    begin 
        m00_axi_aclk <= '0';
        wait for T/2;
        m00_axi_aclk <= '1';
        wait for T/2;
    end process;
    
    -- ******************************************
    -- aresetn
    -- ******************************************
    -- aresetn asserted for T/2
    m00_axi_aresetn <= '0', '1' after T/2
    
    -- ******************************************
    -- other stimulus
    -- ******************************************
    process 
    begin 
        prog_rxen <= '1';
        prog_txen <= '1';
        wait for 4*T;
        
        prog_d     <=  x"00"
        prog_rxen  <=  '0';
        wait until falling_edge(m00_axi_aclk)
        
        prog_d     <=  x"00"
        prog_rxen  <=  '0';
        wait until falling_edge(m00_axi_aclk)
        
    end process;
end tb_arch;