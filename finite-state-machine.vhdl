----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Alessandra Pasini - marticola 843807
-- 
-- Create Date: 17.03.2018 21:53:34
-- Design Name: 
-- Module Name: project_reti_logiche
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity project_reti_logiche is 
    port (
            i_clk         : in  std_logic;
            i_start       : in  std_logic;
            i_rst         : in  std_logic;
            i_data       : in  std_logic_vector(7 downto 0); --1 byte
            o_address     : out std_logic_vector(15 downto 0); --16 bit addr: max size is 255*255 + 3 more for max x and y and thresh.
            o_done            : out std_logic;
            o_en         : out std_logic;
            o_we       : out std_logic;
            o_data            : out std_logic_vector (7 downto 0)
          );
end project_reti_logiche;

architecture FSM of project_reti_logiche is
type state_type is (RST, S0, S1, S2, S3);
signal next_state, current_state: state_type;
signal col,row,threshold: std_logic_vector(7 downto 0);
signal count_col, count_row: std_logic_vector(7 downto 0):= "00000000";
signal lenght, high: std_logic_vector(7 downto 0);
signal sx_col, dx_col, high_row, low_row: std_logic_vector(7 downto 0):= "00000000"; 
signal count_addr: std_logic_vector(15 downto 0):= "0000000000000010";
signal i:std_logic_vector(15 downto 0):= "0000000000000001";
signal sign, s, c, k, r: std_logic;
signal inc : std_logic_vector(7 downto 0):= "00000001";
signal keep_going: std_logic :='0';
signal area: std_logic_vector(15 downto 0);

begin
    o_address <= count_addr; 
    state_reg : process(i_clk)                 --probabilmente i_rst superficiale, lho tolto
    begin
        if (i_clk'event and i_clk='1') then     --messo qui il controllo sul fronte del clock
            if (i_rst = '1') then               
                current_state <= RST;
            else--if (i_clk'event and i_clk='1') then                            --tolto il controllo sul clock che ho messo sopra
                current_state <= next_state; 
            end if;
        end if;
    end process;


    delta_lambda: process(i_clk) 
    begin
      if (i_clk'event and i_clk='1') then        
        case current_state is
            when RST =>
                if(i_start = '1') then                      --sbagliato, start non rimane a uno quindi dopo al primo clock torna a rst la macchina e ci rimane
                    next_state <= S0;
                    o_en <= '1';
                    o_we <= '0';
                    keep_going <='1';
                elsif(keep_going ='1') then                 --aggiunto questo con il segnale keep_going che rimane a 1 per sempre dopo lo start e controllo su di lui ogni volta
                    next_state <= S0;
                    o_en <= '1';
                    o_we <= '0';
                else    
                    next_state <= RST;
                    o_en <= '0';
                end if;
            when S0 =>
                if(count_addr >= "0000000000000110") then
                    next_state <= S1;
                    o_en <= '0';
                    sign <= '1';
                elsif(count_addr >= "0000000000000101") then
                    next_state <= S0;
                    o_en <= '1';
                    threshold <= i_data;
                    count_addr <= count_addr + i;
                elsif(count_addr = "0000000000000100") then
                    next_state <= S0;
                    o_en <= '1';
                    row <= i_data;
                    high_row <= i_data;
                    low_row <= "00000000";
                    count_addr <= count_addr +i;
                elsif (count_addr = "0000000000000011") then            
                    next_state <= S0;
                    o_en <= '1'; 
                    col <= i_data;
                    sx_col <= i_data;
                    dx_col <= "00000000";
                    count_addr <= count_addr +i;     
                elsif (count_addr = "0000000000000010") then            --aggiunto il caso addr=2 che aumenta e basta visto che gli altri li ho aumentati di uno
                    next_state <= S0;
                    o_en <= '1'; 
                    count_addr <= count_addr +i;                                 
                end if;
            when S1 =>
                if (sign = '1') then
                    next_state <= S0;
                    if (count_col <= col) then
                        if (i_data >= threshold) then
                            if(count_row <= high_row ) then
                                high_row <= count_row;
                            end if;
                            if(low_row = "00000000" or count_row > low_row) then
                                low_row <= count_row;
                            end if;
                            if (count_col < sx_col) then
                                sx_col <= count_col;
                            end if;
                            if (dx_col = "00000000" or count_col > dx_col) then
                                dx_col<= count_col;  
                            end if; 
                        end if;
                    end if; 
                    o_en <= '1';
                    sign <= '0';
                    count_addr <= count_addr + i;
                    if (count_col = col) then 
                        count_col <= "00000000";
                        if(count_row < row) then
                            count_row <= count_row + inc;
                        else
                            next_state <= S2;
                            count_addr <= "0000000000000000";
                            k <= '1';   
                            r <= '0';                       
                    end if;
                    else
                        count_col <= count_col + inc;
                    end if;
                end if;
            when S2 =>
                lenght <= dx_col - sx_col;
                high <= low_row - high_row;  
                area <= high * lenght;
                s<= '1';
                o_we <= '1';                
                next_state <= S3;                    
           when S3 =>
                if( s ='1') then 
                     if (count_addr =  "0000000000000000" and k = '1') then                                       
                        next_state <= S2;
                        s <= '0';
                        k <= '0';
                    elsif (count_addr =  "0000000000000000" and k = '0' and r = '0') then 
                        o_data <= area(7 downto 0);
                        next_state <= S2;
                        o_we <= '1';
                        s <= '0'; 
                        r <= '1';
                    elsif (count_addr =  "0000000000000000" and r = '1') then
                        count_addr <= count_addr + i; 
                        next_state <= S2;
                        o_we <= '1';
                        s <= '0';                                
                        k <= '1';                   
                    elsif (count_addr = "0000000000000001" and k = '1') then 
                        o_data <= area(15 downto 8);
                        next_state <= S2;
                        s <= '0';
                        k <= '0';
                    elsif (count_addr = "0000000000000001" and k = '0') then    
                        c <= '1';
                        s <= '0';
                        o_en <= '0';
                        o_we <= '0';
                        o_done <= '1';
                    end if;                                         
                end if; 
                if ( c = '1') then 
                    o_done <= '0'; 
                    count_addr <= count_addr +i;
                    count_col <= "00000000";
                    count_row <= "00000000";
                    keep_going <= '0';
                    r <= '1';
                    c <= '0';                    
                    next_state <= RST;
                    
                end if;             
        end case;
      end if;
    end process;
end FSM;
