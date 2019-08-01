---------------------------------------------------------------------------------------------------
--- Version 2.0 (Speed: ~ 7MB/s)
--- Last modified date: 03/01/2019  
--- Modified by: Mr. Tung Le Thanh
--- Reviewed by: Mr. Duc Do Truong Minh
--- IP Core works as an interface between MIG Memory & FTDI in Asynchronous Mode
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity ft2232h_mem_v0_1 is
    generic (
        -- Users to add parameters here

        -- User parameters ends
        -- Do not modify the parameters beyond this line

        -- Parameters of Axi Master Bus Interface M00_AXI
        C_M00_AXI_ID_WIDTH      : integer   := 1;
        C_M00_AXI_ADDR_WIDTH    : integer   := 32;
        C_M00_AXI_DATA_WIDTH    : integer   := 128;
        C_M00_AXI_AWUSER_WIDTH  : integer   := 0;
        C_M00_AXI_ARUSER_WIDTH  : integer   := 0;
        C_M00_AXI_WUSER_WIDTH   : integer   := 0;
        C_M00_AXI_RUSER_WIDTH   : integer   := 0;
        C_M00_AXI_BUSER_WIDTH   : integer   := 0
    );
    port (
        -- Users to add ports here
        prog_d     : inout std_logic_vector(7 downto 0);       -- Data sent/received by FTDI chip
        prog_rxen  : in std_logic;
        prog_txen  : in std_logic;
        prog_rdn   : out std_logic;
        prog_wrn   : out std_logic;
        prog_siwun : out std_logic;
        -- User ports ends
        
        -- Do not modify the ports beyond this line
        
        -- Ports of Axi Master Bus Interface M00_AXI
        m00_axi_aclk    : in std_logic;                        -- Clock from system (MIG)
        m00_axi_aresetn : in std_logic;
        m00_axi_awid    : out std_logic_vector(C_M00_AXI_ID_WIDTH-1 downto 0);
        m00_axi_awaddr  : out std_logic_vector(C_M00_AXI_ADDR_WIDTH-1 downto 0);
        m00_axi_awlen   : out std_logic_vector(7 downto 0);
        m00_axi_awsize  : out std_logic_vector(2 downto 0);
        m00_axi_awburst : out std_logic_vector(1 downto 0);
        m00_axi_awlock  : out std_logic;
        m00_axi_awcache : out std_logic_vector(3 downto 0);
        m00_axi_awprot  : out std_logic_vector(2 downto 0);
        m00_axi_awqos   : out std_logic_vector(3 downto 0);
        m00_axi_awuser  : out std_logic_vector(C_M00_AXI_AWUSER_WIDTH-1 downto 0);
        m00_axi_awvalid : out std_logic;
        m00_axi_awready : in std_logic;
        m00_axi_wdata   : out std_logic_vector(C_M00_AXI_DATA_WIDTH-1 downto 0);
        m00_axi_wstrb   : out std_logic_vector(C_M00_AXI_DATA_WIDTH/8-1 downto 0);
        m00_axi_wlast   : out std_logic;
        m00_axi_wuser   : out std_logic_vector(C_M00_AXI_WUSER_WIDTH-1 downto 0);
        m00_axi_wvalid  : out std_logic;
        m00_axi_wready  : in std_logic;
        m00_axi_bid     : in std_logic_vector(C_M00_AXI_ID_WIDTH-1 downto 0);
        m00_axi_bresp   : in std_logic_vector(1 downto 0);
        m00_axi_buser   : in std_logic_vector(C_M00_AXI_BUSER_WIDTH-1 downto 0);
        m00_axi_bvalid  : in std_logic;
        m00_axi_bready  : out std_logic;
        m00_axi_arid    : out std_logic_vector(C_M00_AXI_ID_WIDTH-1 downto 0);
        m00_axi_araddr  : out std_logic_vector(C_M00_AXI_ADDR_WIDTH-1 downto 0);
        m00_axi_arlen   : out std_logic_vector(7 downto 0);
        m00_axi_arsize  : out std_logic_vector(2 downto 0);
        m00_axi_arburst : out std_logic_vector(1 downto 0);
        m00_axi_arlock  : out std_logic;
        m00_axi_arcache : out std_logic_vector(3 downto 0);
        m00_axi_arprot  : out std_logic_vector(2 downto 0);
        m00_axi_arqos   : out std_logic_vector(3 downto 0);
        m00_axi_aruser  : out std_logic_vector(C_M00_AXI_ARUSER_WIDTH-1 downto 0);
        m00_axi_arvalid : out std_logic;
        m00_axi_arready : in std_logic;
        m00_axi_rid     : in std_logic_vector(C_M00_AXI_ID_WIDTH-1 downto 0);
        m00_axi_rdata   : in std_logic_vector(C_M00_AXI_DATA_WIDTH-1 downto 0);
        m00_axi_rresp   : in std_logic_vector(1 downto 0);
        m00_axi_rlast   : in std_logic;
        m00_axi_ruser   : in std_logic_vector(C_M00_AXI_RUSER_WIDTH-1 downto 0);
        m00_axi_rvalid  : in std_logic;
        m00_axi_rready  : out std_logic
    );
end ft2232h_mem_v0_1;

architecture arch_imp of ft2232h_mem_v0_1 is
    type usb_state_t is (
        usb_init_state, usb_inc_addr, usb_setup_address, usb_send_raddr, usb_wait_raddr,
        usb_accept_data, usb_wait_for_data, usb_read_data, usb_pulse_wr, usb_read_data_wait
    );
    
    type burst_size_t is array(Natural range <>) of std_logic_vector(m00_axi_awsize'range);
    
    constant burst_size : burst_size_t(1 to 16) := (
        1 => "000",
        2 => "001",
        4 => "010",
        8 => "011",
        16 => "100",
        others => "000"
    );
    
    -- State of the USB transmission
    constant data_bytes : integer := (C_M00_AXI_DATA_WIDTH/8);
    
    -- FT2232H Asynchronous timings:
    constant max_counter_cycles : integer  := 3;
    constant wr_pulse_cycles    : integer  := 3;
    constant wr_setup_cycles    : integer  := 1;
    constant MIN_ADDRESS        : unsigned := x"80000000";
    constant MAX_ADDRESS        : unsigned := x"8972C000";
    
    signal counter           :  integer range 0 to max_counter_cycles-1;
    signal usb_state         :  usb_state_t;                                        -- Address/data state
    signal data_read_byte    :  integer range 0 to data_bytes-1;                    -- Index of the data byte being read
    signal address_buffer    :  unsigned(m00_axi_awaddr'range);
    signal data_read_buffer  :  std_logic_vector(m00_axi_wdata'range);
    signal data_write_buffer :  std_logic_vector(m00_axi_rdata'range);   
    
    signal counter_wait      :  integer range 0 to 777777;
begin
    -- Value of plenty of unused signals
    m00_axi_awid    <= (others => '0');
    m00_axi_awlen   <= (others => '0');
    m00_axi_awsize  <= burst_size(data_bytes);
    m00_axi_awburst <= (others => '0');
    m00_axi_awlock  <= '0';
    m00_axi_awcache <= (others => '0');
    m00_axi_awprot  <= (others => '0');
    m00_axi_awqos   <= (others => '0');
    m00_axi_awuser  <= (others => '0');
    m00_axi_wstrb   <= (others => '1');
    m00_axi_wlast   <= '1';
    m00_axi_wuser   <= (others => '0');
    m00_axi_bready  <= '1';
    m00_axi_arid    <= (others => '0');
    m00_axi_arlen   <= (others => '0');
    m00_axi_arsize  <= burst_size(data_bytes);
    m00_axi_arburst <= (others => '0');
    m00_axi_arlock  <= '0';
    m00_axi_arcache <= (others => '0');
    m00_axi_arprot  <= (others => '0');
    m00_axi_arqos   <= (others => '0');
    m00_axi_aruser  <= (others => '0');

    -- Write responses from read requests on the USB bus
    process(m00_axi_aclk)
    begin
        if rising_edge(m00_axi_aclk) then
            if m00_axi_aresetn = '0' then
                prog_d      <= (others => 'Z');
                prog_rdn    <= '1';
                prog_wrn    <= '1';
                prog_siwun  <= '1';
                
                usb_state       <= usb_init_state;
                address_buffer  <= MIN_ADDRESS;
                data_read_byte  <= 0;
                counter         <= 0;
                
                m00_axi_awaddr  <= (others => '0');
                m00_axi_awvalid <= '0';
                m00_axi_araddr  <= (others => '0');
                m00_axi_arvalid <= '0';
                m00_axi_wdata   <= (others => '0');
                m00_axi_wvalid  <= '0';
                m00_axi_rready  <= '0';
            elsif counter > 0 then
                counter  <= counter - 1;
            elsif counter = 0 then 
                prog_rdn <= '1';
                prog_wrn <= '1';
                prog_d   <= (others => 'Z');
                case usb_state is
                    when usb_init_state =>
                        if prog_rxen = '0' then
                            usb_state <= usb_setup_address;
                        end if;
                    when usb_inc_addr =>
                        address_buffer <= address_buffer + 16;
                        usb_state <= usb_setup_address;
                    when usb_setup_address =>
                        usb_state <= usb_send_raddr;
                    when usb_send_raddr =>
                        -- Send a read request
                        m00_axi_araddr <= std_logic_vector(address_buffer);
                        m00_axi_arvalid <= '1';
                        usb_state <= usb_wait_raddr;
                    when usb_wait_raddr =>
                        -- Wait for the read request to be accepted
                        if m00_axi_arready = '1' then
                            m00_axi_arvalid <= '0';
                            usb_state <= usb_accept_data;
                        end if;
                    when usb_accept_data =>
                        -- Tell the AXI bus that we are ready to read
                        m00_axi_rready <= '1';
                        usb_state <= usb_wait_for_data;
                    when usb_wait_for_data =>
                        -- Wait for data on the AXI bus
                        if m00_axi_rvalid = '1' then
                            m00_axi_rready <= '0';
                            data_read_buffer <= m00_axi_rdata;
                            usb_state <= usb_read_data;
                        end if;
                    when usb_read_data =>
                        -- Transmit data on the USB connection
                        if prog_txen = '0' then
                            prog_d <= data_read_buffer(data_read_byte*8 + 7 downto data_read_byte*8);
                            -- Setup data bus before changing writen pin
                            counter <= wr_setup_cycles - 1;
                            usb_state <= usb_pulse_wr;
                        else 
                            if counter_wait > 699999 then 
                                address_buffer <= MIN_ADDRESS;
                                usb_state <= usb_init_state;
                            end if;
                        end if;
                    when usb_pulse_wr =>
                        prog_wrn <= '0';
                        -- Hold writen pin to logic 0
                        counter <= wr_pulse_cycles - 1;
                        usb_state <= usb_read_data_wait; 
                    when usb_read_data_wait =>
                        -- Pull writen to logic 1 again
                        prog_wrn <= '1';
                        -- Let time to prog_txen to be updated
                        if data_read_byte = data_bytes-1 then
                            -- Everything has been read, start a new request
                            data_read_byte <= 0;
                            usb_state <= usb_inc_addr;
                        else
                            -- Read next byte
                            data_read_byte <= data_read_byte + 1;
                            usb_state <= usb_read_data;
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    process(m00_axi_aclk)
    begin
        if rising_edge(m00_axi_aclk) then
            if m00_axi_aresetn = '0' or prog_txen = '0' then
                counter_wait <= 0;
            else
                counter_wait <= counter_wait + 1;
            end if;
        end if;
    end process;
    
end arch_imp;
