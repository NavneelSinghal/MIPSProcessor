library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity processor is
  Port (
         fclk: in std_logic;
         reset: in std_logic; --to start the implementation
         toggle: in std_logic; --1 if we need to find clock cycles, 0 otherwise
         seg: out std_logic_vector (6 downto 0);
         an: out std_logic_vector (3 downto 0)
        );
end processor;

architecture Behavioral of processor is 

type state_type is (start, idle, proc, lw2, sw2, lw3, sw3, memwait, finish);
type register_file is array(31 downto 0) of std_logic_vector(31 downto 0);

signal state: state_type := idle;
signal reg: register_file;

signal addra: std_logic_vector(11 downto 0) := "000000000000";
signal addrb: std_logic_vector(11 downto 0);
signal wea: std_logic_vector(0 downto 0) := "0";
signal web: std_logic_vector(0 downto 0) := "0";
signal dina: std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
signal dinb: std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
signal douta: std_logic_vector(31 downto 0);
signal doutb: std_logic_vector(31 downto 0);

signal src1: integer := 0;
signal src2: integer := 0;
signal dest: integer := 0;
signal lastaddr: integer := 0;
signal slowclock: std_logic := '0';
signal slowcnt: integer := 0;
signal memcnt: integer := 0;
signal clk: std_logic := '0';
signal clkcnt: integer := 0;

signal outled: std_logic_vector (15 downto 0);
signal displ: std_logic_vector (15 downto 0);
signal cycles: integer;
signal cycdispl: std_logic_vector (15 downto 0);
signal previnstr: std_logic := '0';
signal notclk: std_logic;

signal tempaddra: std_logic_vector (11 downto 0);
signal tempdouta: std_logic_vector (31 downto 0);

signal first: std_logic := '1';

component blk_mem_gen_0
port(
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    clkb : IN STD_LOGIC;
    web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dinb : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
end component;

component seven
port(
    clock_100Mhz : in STD_LOGIC;-- 100Mhz clock on Basys 3 FPGA board
    reset : in STD_LOGIC; -- reset
    Anode_Activate : out STD_LOGIC_VECTOR (3 downto 0);-- 4 Anode signals
    LED_out : out STD_LOGIC_VECTOR (6 downto 0);-- Cathode patterns of 7-segment display
    displ : in std_logic_vector(15 downto 0)
  );
end component;

begin

process(fclk)
begin
    if(fclk = '1' and fclk'event) then
        clkcnt <= clkcnt + 1;
        if(clkcnt = 50) then clk <= not clk; clkcnt <= 0;
        end if;
    end if;
end process;

process(clk)
begin
if(clk = '1' and clk'event) then
    slowcnt <= slowcnt + 1;
    if(slowcnt = 50000) then 
        slowcnt <= 0;
        slowclock <= not slowclock;
    end if;
end if;
end process;

notclk <= not clk;

memory: blk_mem_gen_0 port map(
    clka => fclk, --changed this to faster clock
    clkb => fclk, --and this
    wea => wea,
    web => web,
    addra => addra,
    addrb => addrb,
    dina => dina,
    dinb => dinb,
    douta => douta,
    doutb => doutb
);

sevenseg: seven port map(
    clock_100Mhz => fclk,
    reset => reset,
    Anode_Activate => an,
    LED_out => seg,
    displ => outled
);

src1 <= to_integer(unsigned(douta(25 downto 21)));
cycdispl <= std_logic_vector(to_unsigned(cycles, 16));
with toggle select outled <= cycdispl when '1',
                            displ when others;
                            
dest <= to_integer(unsigned(douta(15 downto 11)));
src2 <= to_integer(unsigned(douta(20 downto 16)));


addrb <= std_logic_vector(to_unsigned(to_integer(signed(douta(15 downto 0))) + 1024 + to_integer(signed(reg(src1))), 12));


process (clk)
begin

if(clk = '1' and clk'event) then
    case state is 
    when idle => 
        if(reset = '1') then
            state <= proc;
            addra <= std_logic_vector(to_unsigned(memcnt, 12));
            memcnt <= memcnt + 1;
            if(first = '1') then 
            for i in 0 to 31 loop
                reg(i) <= "00000000000000000000000000000000";
            end loop;   
            reg(29) <= "00000000000000000000111111111111";
            first <= '0';
            end if;
        end if;
        
    when proc =>
        case douta (31 downto 26) is 
            when "000000" =>
                case douta (5 downto 0) is 
                    when "100000" => --add
                        reg(dest) <= std_logic_vector(signed(reg(src1)) + signed(reg(src2)));
                        lastaddr <= dest;
                        cycles <= cycles + 1;
                        addra <= std_logic_vector(to_unsigned(memcnt, 12));
                        memcnt <= memcnt + 1;
                    when "100010" => --sub
                        reg(dest) <= std_logic_vector(signed(reg(src1)) - signed(reg(src2)));
                        lastaddr <= dest;
                        cycles <= cycles + 1;
                        addra <= std_logic_vector(to_unsigned(memcnt, 12));
                        memcnt <= memcnt + 1;
                    when "000000" => --sll
                        case douta (25 downto 6) is 
                            when "00000000000000000000" => --program over
                                state <= finish;
                                memcnt <= 0;
                                displ <= reg(lastaddr) (15 downto 0);
                            when others => --sll
                                reg(dest) <= std_logic_vector(shift_left(unsigned(reg(src2)), to_integer(unsigned(douta (10 downto 6)))));
                                cycles <= cycles + 1;
                                lastaddr <= dest;
                                addra <= std_logic_vector(to_unsigned(memcnt, 12));
                                memcnt <= memcnt + 1;
                        end case;
                    when "000010" => --srl
                        reg(dest) <= std_logic_vector(shift_right(unsigned(reg(src2)), to_integer(unsigned(douta (10 downto 6)))));
                        cycles <= cycles + 1;
                        lastaddr <= dest;
                        addra <= std_logic_vector(to_unsigned(memcnt, 12));
                        memcnt <= memcnt + 1;
                    when "001000" => --jr
                        addra <= "00" & reg(src1)(9 downto 0);
                        memcnt <= to_integer(unsigned(reg(src1)(9 downto 0)))+1;
                        cycles <= cycles + 1;
                    when others => 
                        addra <= std_logic_vector(to_unsigned(memcnt, 12));
                        memcnt <= memcnt + 1;
                        cycles <= cycles + 1;
                end case;
            when "100011" => --lw
                web <= "0";
                state <= lw2;
                cycles <= cycles + 1;
                lastaddr <= src2;
            when "101011" => --sw
                web <= "1";
                dinb <= reg(src2);
                state <= sw2;
                cycles <= cycles + 1;
                lastaddr <= src2;
            when "001000" => --addi
                reg(src2) <= std_logic_vector(signed(reg(src1)) + signed(douta(15 downto 0)));
                lastaddr <= src2;
                cycles <= cycles + 1;
                addra <= std_logic_vector(to_unsigned(memcnt, 12));
                memcnt <= memcnt + 1;
            when "000101" => -- bne 
                if(to_integer(signed(reg(src1))) /= to_integer(signed(reg(src2)))) then
                    addra <= std_logic_vector(to_unsigned(memcnt + to_integer(signed(douta(15 downto 0))), 12));
                    memcnt <= memcnt + to_integer(signed(douta(15 downto 0))) + 1;
                    -- the last instruction cannot be a jump instruction so we don't have to store anything, incase if it jumps to the end of the program, then the target register will be the register previous to the jump instruction
                else
                    addra <= std_logic_vector(to_unsigned(memcnt, 12));
                    memcnt <= memcnt + 1;
                end if;
                cycles <= cycles + 1;
            when "000100" => --beq
                if(to_integer(signed(reg(src1))) = to_integer(signed(reg(src2)))) then
                    addra <= std_logic_vector(to_unsigned(memcnt + to_integer(signed(douta(15 downto 0))), 12));
                    memcnt <= memcnt + to_integer(signed(douta(15 downto 0))) + 1;
                    -- the last instruction cannot be a jump instruction so we don't have to store anything, incase if it jumps to the end of the program, then the target register will be the register previous to the jump instruction
                else
                    addra <= std_logic_vector(to_unsigned(memcnt, 12));
                    memcnt <= memcnt + 1;
                end if;
                cycles <= cycles + 1;
            when "000110" => --blez
                if(reg(src1)(31) = '1' or reg(src1) = "00000000000000000000000000000000") then
                    addra <= std_logic_vector(to_unsigned(memcnt + to_integer(signed(douta(15 downto 0))), 12));
                    memcnt <= memcnt + to_integer(signed(douta(15 downto 0))) + 1;                    -- the last instruction cannot be a jump instruction so we don't have to store anything, incase if it jumps to the end of the program, then the target register will be the register previous to the jump instruction
                else
                    addra <= std_logic_vector(to_unsigned(memcnt, 12));
                    memcnt <= memcnt + 1;
                end if;
                cycles <= cycles + 1;
            when "000111" => --bgtz
                if(not(reg(src1)(31) = '1' or reg(src1) = "00000000000000000000000000000000")) then
                    addra <= std_logic_vector(to_unsigned(memcnt + to_integer(signed(douta(15 downto 0))), 12));
                    memcnt <= memcnt + to_integer(signed(douta(15 downto 0))) + 1;
                    -- the last instruction cannot be a jump instruction so we don't have to store anything, incase if it jumps to the end of the program, then the target register will be the register previous to the jump instruction
                else
                    addra <= std_logic_vector(to_unsigned(memcnt, 12));
                    memcnt <= memcnt + 1;
                end if;
                cycles <= cycles + 1;
            when "000010" => --j
                addra <= "00" & douta(9 downto 0);
                memcnt <= to_integer(unsigned(douta(9 downto 0)))+1;
                cycles <= cycles + 1;
            when "000011" => --jal
                reg(31) <= std_logic_vector(to_unsigned(memcnt,32));
                addra <= "00" & douta(9 downto 0);
                memcnt <= to_integer(unsigned(douta(9 downto 0)))+1;
                cycles <= cycles + 1;
            when others => 
                addra <= std_logic_vector(to_unsigned(memcnt, 12));
                memcnt <= memcnt + 1;
                cycles <= cycles + 1;
        end case;
        
    when lw2 => 
        cycles <= cycles + 1;
        reg(src2) <= doutb;
        state <= proc; --not using memwait
        addra <= std_logic_vector(to_unsigned(memcnt, 12));
        memcnt <= memcnt + 1;
        displ <= reg(src2) (15 downto 0);
    when sw2 =>
        cycles <= cycles + 1;
        web <= "0";
        state <= proc; --not using memwait
        addra <= std_logic_vector(to_unsigned(memcnt, 12));
        memcnt <= memcnt + 1;
        displ <= reg(src2) (15 downto 0);
    when others =>
        displ <= reg(lastaddr) (15 downto 0);
        if(reset = '0') then state <= idle; end if;
    end case;
end if;
end process;

end Behavioral;