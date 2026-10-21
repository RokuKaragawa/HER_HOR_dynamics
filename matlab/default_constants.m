function c = default_constants()
%DEFAULT_CONSTANTS  内置物理常数（可被输入 CSV 的 kB / h 列覆盖）
%   对应 Python calculator.py 中的 DEFAULT_KB / DEFAULT_H。
%     kB : 玻尔兹曼常数 (eV/K)
%     h  : 普朗克常数 (eV*s)

    c.kB = 8.617333262145e-5;
    c.h  = 4.135667662e-15;
end
