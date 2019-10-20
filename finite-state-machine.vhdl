----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Alessandra Pasini 
-- 
-- Create Date: 30.03.2018 00:02:30
-- Design Name: 
-- Module Name: project_reti_logiche - Behavioral
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
type state_type is (RST, S0, S1, S2, S3);  --stati dell'FSM
signal next_state, current_state: state_type;
signal col,row,threshold: std_logic_vector(7 downto 0); --segnali atti a salvare le dimensioni della matrice e il valore soglia
signal count_col, count_row: std_logic_vector(7 downto 0);  --contatori utilizzati durante la lettura della matrice
signal lenght, high: std_logic_vector(7 downto 0);  --terminata la lettura della matrice si salvano qui le lunghezze di base e altezza
signal sx_col, dx_col, high_row, low_row: std_logic_vector(7 downto 0); --4 segnali atti a salvare gli estremi dell'immagine
signal count_addr: std_logic_vector(15 downto 0):= "0000000000000010";  --contatore per gli indirizzi in memoria
signal i:std_logic_vector(15 downto 0); --incremento dell'indirizzo
signal sign, s, c, k, r: std_logic; --segnali vari
signal inc : std_logic_vector(7 downto 0);  --incremento contatori righe e colonne
signal keep_going: std_logic :='0';          
--segnale che impedisce al processo di interrompersi nel caso venga inviato erroneamente un segnale di start
signal area: std_logic_vector(15 downto 0);  --segnale nel quale si salva l'area massima trovata

begin
    o_address <= count_addr; 
    state_reg : process(i_clk)                
    begin
        if (i_clk'event and i_clk='1') then    
            if (i_rst = '1') then              
                current_state <= RST; 
            else                              
                current_state <= next_state; 
            end if;
        end if;
    end process;


    delta_lambda: process(i_clk) 
    begin
      if (i_clk'event and i_clk='1') then        
        case current_state is
            when RST =>                     --stato di inizializzazione
                if(i_start = '1') then      --il seganle di start alto indica l'inizio effettivo della computazione                      
                    next_state <= S0;       --lo stato prossimo è S0
                    o_en <= '1';            --porre l'uscita o_en alta fa si che possano essere effettuate delle operaioni sulla memoria
                    o_we <= '0';            --l'uscita o_we = 0 segnala il fatto che si voglia leggere la memoria
                    keep_going <='1';       --dalla riga 89 alla riga 98 si inizializzano vari segnali
                    count_col <= "00000000";
                    count_row <= "00000000";
                    i <= "0000000000000001";
                    count_addr <= "0000000000000010";
                    inc <= "00000001";
                    r <= '0';
                    c <= '0';
                    k <= '0';
                    s <= '0';
                elsif(keep_going ='1') then --se per errore si torna in questo stato, ovvero senza che ci sia stato un segnale di rst 
                    next_state <= S0;       --si va allo stato successivo
                    o_en <= '1';
                    o_we <= '0';
                elsif( i_rst = '1') then    --se si ha ha un secondo segnale di rst si resta nello stato di RST
                    next_state <= RST;
                    keep_going <= '0';      --torna a zero in quanto si vuole ricominciare la computazione
                else    
                    next_state <= RST;      --si resta in attesa di un segnale di start
                    o_en <= '0';
                end if;
            when S0 =>
                if (sign = '1') then
                    if (count_addr = "0000000000000010") then       --se l'indirizzo è 0x02 si sta prelevando il dato corrispondente al numero di colonne
                        next_state <= S0;       --si impone che lo stato successivo siauguale a quello corrente
                        col <= i_data;          --il segnale col è posto uguale al dato letto
                        o_en <= '1';            
                        sx_col <= i_data;       --si inizializza il segnale sx_col ponendolo uguale al dato in ingresso
                        dx_col <= "00000000";   --si inizializza il segnale dx-col ponendolo uguale a 0
                    elsif (count_addr = "0000000000000011") then    --se l'indirizzo è 0x03 si sta prelevando il dato corrispondente al numero di righe
                        if( i_data = col) then  --nelle letture iniziali si è individuato un ritardo; questo controllo serve per impedire
                            next_state <= S0;   --che nel segnale row venga scritto un dato errato corrispondente al numero di colonne e non di righe
                        else
                            next_state <= S0;   
                            row <= i_data;          --il segnale row è posto uguale al dato letto
                            high_row <= i_data;     --si inizializza il segnale high_row ponendolo uguale al dato in ingresso
                            low_row <= "00000000";  --si inizializza il segnale low_row ponendolo uguale a 0
                        end if;
                    elsif (count_addr = "0000000000000100") then    --se l'indirizzo è 0x04 si sta prelevando il dato corrispondente al valore di soglia
                        if( i_data = row) then  --nelle letture iniziali si è individuato un ritardo; questo controllo serve per impedire
                            next_state <= S0;   --che nel segnale threshold venga scritto un dato errato corrispondente al numero di righe
                        else
                            next_state <= S0;
                            threshold <= i_data;    --il segnale threshold è posto uguale al dato letto
                            r <= '1';
                        end if; 
                    end if; 
                sign <= '0';  
                count_addr <= count_addr +inc;  --si incrementa il contatore dell'indirizzo di un'unità
                else 
                    sign <= '1'; 
                    if (count_addr = "0000000000000101") then   --se l'indirizzo è 0x05 si sta prelevando il primo elemento della matrice
                        if( r = '1') then    --nelle letture iniziali si è individuato un ritardo; questo controllo serve per impedire
                            next_state <= S0;           --che si passi allo stato successivo come primo valore quello di soglia
                            sign <= '0';
                            r <= '0';
                        else
                            next_state <= S1;   --si passa allo stato successivo in quanto si è concluso il primo step del processo
                        end if;                  
                    end if;
                end if;
                if (i_rst = '1') then
                    next_state <= RST;
                end if; 
            when S1 =>
                    if (count_col < col) then                   --se il dato in ingresso ha un valore pari o superiore a quello della soglia
                        if (i_data >= threshold) then           --si provede a ricalcolare i 4 valori necessari per calcolare i lati dell'immagine 
                            if(count_row <= high_row ) then     --se il contatore delle righe ha valore inferiore a quello di high_row allora
                                high_row <= count_row;          --si sostituisce quest'ultimo con il valore di count_row                   
                            end if;                             
                            if(count_row > low_row) then        --se il contatore delle righe ha valore uguale o superiore a quello di low_row allora
                                low_row <= count_row;           --si sostituisce quest'ultimo con il valore di count_row
                            end if;
                            if (count_col < sx_col) then        --se il contatore delle colonne ha valore inferiore a quello di sx_col allora
                                sx_col <= count_col;            --si sostituisce quest'ultimo con il valore di count_col                  
                            end if;
                            if ( count_col >= dx_col) then      --se il contatore delle colonne ha valore uguale o superiore a quello di dx_col allora
                                dx_col<= count_col;             --si sostituisce quest'ultimo con il valore di count_col
                            end if; 
                        end if; 
                    end if;
                    o_en <= '1';
                    if (count_col = (col-inc)) then             --se il contatore delle colonne ha valore pari alla dimensione M della matrice
                        count_col <= "00000000";                --si deve azzerare tale contatore ed incrementare quello delle righe
                        if(count_row < (row- inc)) then         --fintantochè il contatore delle righe è inferiore alla dimensione N della matrice
                            count_row <= count_row + inc;       --si incrementa di uno
                            count_addr <= count_addr + i;       --si incrementa di uno count_addr
                            next_state <= S1;                   --lo stato prossimo corrisponde allo stato corrente
                        else
                            if (sx_col > dx_col) then           --se il contatore delle righe è pari alla dimensione N della matrice si è giunti
                               sx_col <= dx_col;                --all'ultimo elemento della matrice
                               end if;
                            if (high_row > low_row) then
                                high_row <= low_row;
                            end if;
                            count_col <= col;
                            next_state <= S2;                   --lo stato prossimo corrisponde a S2 in quanto è terminata la lettura della matrice
                            count_addr <= "0000000000000000";   --count_addr = 0x00 in quanto questo è il primo indirizzo in cui si scrive                   
                        end if;
                    elsif (count_col < (col-inc)) then      --se il contatore delle colonne ha valore inferiore alla dimensione M della matrice
                        count_addr <= count_addr + i;       --incremento sia il suo valore che quello dell'indirizzo di uno 
                        count_col <= count_col + inc;
                        next_state <= S1;                   --lo stato prossimo corrisponde allo stato corrente
                    end if;
                    if (i_rst = '1') then                   --nel caso in cui ci sia uno stato di reset = 1 lo stato prossimo corrisponde a RST                
                        next_state <= RST;  
                    end if;
            when S2 => 
                if(sx_col = "00000000" and dx_col = "00000000" and low_row = "00000000" and high_row = "00000000") then          
                    lenght <= dx_col - sx_col;          --se non vi sono elementi con valore pari o superiore alla soglia base ed altezza sono nulli
                    high <= low_row - high_row;  
                else
                    lenght <= dx_col - sx_col + inc;    --in caso contrario si trovano due valori diversi da zero
                    high <=  low_row - high_row + inc; 
                end if;
                area <= high * lenght;                  --si calcola l'area moltiplicando base per altezza
                s<= '1';
                o_we <= '1';                            --si alza il segnale o_we in quanto l'operazione successiva prevede la scrittura in memoria
                next_state <= S3;                       --lo stato prossimo corrisponde a S3
                if (i_rst = '1') then
                    next_state <= RST;                  --nel caso in cui ci sia uno stato di reset = 1 lo stato prossimo corrisponde a RST 
                end if;                  
           when S3 =>
                if( s ='1') then 
                    if (count_addr =  "0000000000000000" and r = '0') then      --scrivo gli 8bit meno significativi all'indirizzo 0x00
                        o_data <= area(7 downto 0);         --il dato in uscita corrisponde agli 8bit meno significativi
                        next_state <= S2;                   --lo stato prossimo corrisponde a S2
                        s <= '0'; 
                        r <= '1';
                    elsif (count_addr =  "0000000000000000" and r = '1') then   
                        count_addr <= count_addr + i;       --incremento l'indirizzo di uno
                        next_state <= S2;                   --lo stato prossimo corrisponde a S2
                        s <= '0';                                
                        k <= '1';                   
                    elsif (count_addr = "0000000000000001" and k = '1') then    --scrivo gli 8bit più significativi all'indirizzo 0x01
                        o_data <= area(15 downto 8);        --il dato in uscita corrisponde agli 8bit più significativi
                        next_state <= S2;                   --lo stato prossimo corrisponde a S2
                        s <= '0';
                        k <= '0';
                    elsif (count_addr = "0000000000000001" and k = '0') then    
                        c <= '1';
                        s <= '0';
                        o_en <= '0';    --non dovendo più compiere alcuna azione con la memoria risulta più neessario tenere alto o_en
                        o_we <= '0';    
                        o_done <= '1';  --avendo completato tutte le operazioni richieste si può alzare o_done
                    end if;                                         
                end if; 
                if ( c = '1') then 
                    o_done <= '0';      --passato un ciclo di clock si può porre o_done = 0
                    count_addr <= count_addr +i;                --incremento di uno l'indirizzo
                    next_state <= RST;                          --si torna allo stato iniziale
                end if;   
                if (i_rst = '1') then
                    next_state <= RST;  --nel caso in cui ci sia uno stato di reset = 1 lo stato prossimo corrisponde a RST
                end if;          
        end case;
      end if;
    end process;
end FSM;
