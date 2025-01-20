library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity irrigador is
    Port (
        WM          : in  std_logic_vector(1 downto 0); -- Estado inicial
        WL          : in  std_logic_vector(7 downto 0); -- Nível de água
        RTC_val     : in  std_logic_vector(7 downto 0); -- Relógio atual
        SMS         : in  std_logic_vector(7 downto 0); -- Informação adicional
        clk         : in  std_logic;                   -- Clock
        reset       : in  std_logic;                   -- Reset global
        WP          : out std_logic;                   -- Ativação da bomba
        timestamp   : out std_logic_vector(7 downto 0) -- Registro de ativação
    );
end entity;

architecture combinational of irrigador is

    -- Sinais internos
    signal RTC_reg       : std_logic_vector(7 downto 0); -- Registro de relógio
    signal time_elapsed  : std_logic_vector(3 downto 0); -- Contador de tempo
    signal state         : std_logic_vector(2 downto 0); -- Estado atual
    signal next_state    : std_logic_vector(2 downto 0); -- Próximo estado
    signal WL_gt_30      : std_logic;                   -- Comparação WL > 30
    signal RTC_in_range  : std_logic;                   -- Comparação RTC_reg entre 8 e 18
    signal SMS_lt_80     : std_logic;                   -- Comparação SMS < 80

begin

    -- Comparador WL > 30
    WL_gt_30 <= '1' when unsigned(WL) > 30 else '0';

    -- Comparador RTC entre 8 e 18
    RTC_in_range <= '1' when unsigned(RTC_reg) > 8 and unsigned(RTC_reg) < 18 else '0';

    -- Comparador SMS < 80
    SMS_lt_80 <= '1' when unsigned(SMS) < 80 else '0';

    -- Multiplexador de estados
    process(state, WM, WL_gt_30, RTC_in_range, SMS_lt_80, time_elapsed)
    begin
        case state is
            when "000" => -- Estado Wait
                if WM = "01" then
                    next_state <= "001"; -- Check
                elsif WM = "10" then
                    next_state <= "010"; -- Water_Level
                else
                    next_state <= "000"; -- Permanece em Wait
                end if;

            when "001" => -- Estado Check
                if RTC_in_range = '1' and SMS_lt_80 = '1' then
                    next_state <= "010"; -- Water_Level
                else
                    next_state <= "000"; -- Volta para Wait
                end if;

            when "010" => -- Estado Water_Level
                if WL_gt_30 = '1' and WM = "01" then
                    next_state <= "011"; -- Irr 1
                elsif WL_gt_30 = '1' and WM = "10" then
                    next_state <= "100"; -- Irr 2
                else
                    next_state <= "000"; -- Volta para Wait
                end if;

            when "011" => -- Estado Irr 1
                next_state <= "101"; -- Temp

            when "100" => -- Estado Irr 2
                next_state <= "101"; -- Temp

            when "101" => -- Estado Temp
                if unsigned(time_elapsed) >= 10 then
                    next_state <= "000"; -- Volta para Wait
                else
                    next_state <= "101"; -- Permanece em Temp
                end if;

            when others => 
                next_state <= "000"; -- Estado padrão: Wait
        end case;
    end process;

    -- Lógica de estado
    process(clk, reset)
    begin
        if reset = '1' then
            state <= "000"; -- Estado inicial: Wait
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;

    -- Conexões de registradores
    process(clk)
    begin
        if rising_edge(clk) then
            case state is
                when "001" => -- Estado Check
                    RTC_reg <= RTC_val;
                when "011" | "100" => -- Estados Irr 1 e Irr 2
                    timestamp <= RTC_val; -- Salva timestamp
                when "101" => -- Estado Temp
                    time_elapsed <= std_logic_vector(unsigned(time_elapsed) + 1); -- Incrementa temporizador
                when others =>
                    time_elapsed <= (others => '0'); -- Reseta temporizador
            end case;
        end if;
    end process;

    -- Saída da bomba
    WP <= '1' when state = "011" or state = "100" else '0';

end combinational;
