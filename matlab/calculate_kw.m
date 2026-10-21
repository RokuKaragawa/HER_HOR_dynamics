function kw = calculate_kw(temperature)
%CALCULATE_KW  水的离子积 Kw(T)
%   对应 Python calculator.py 中的 calculate_kw。
%
%   p_kw = -4.706 + 4470/T - 0.0217*ln(T)
%   kw   = 10^(-p_kw)

    p_kw = -4.706 + 4470.0 ./ temperature - 0.0217 .* log(temperature);
    kw = 10.0 .^ (-p_kw);
end
