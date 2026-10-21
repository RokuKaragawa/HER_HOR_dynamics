function spec = rate_field_order()
%RATE_FIELD_ORDER  34 个速率常数的字段名与顺序
%
%   MATLAB 结构体字段名不能用 '-'（Python 里叫 'A-1'），
%   所以逆反应统一用 'm' 结尾表示减号：'A-1' -> 'Am1'。
%   写出 CSV 时再由 field_to_header 还原成 'A-1'。
%
%   返回：
%     spec.grouped       34 个字段，喂给 solve_coverages 的顺序。
%                        必须与 Python 的 ordered_rate_names 严格一致 ——
%                        【每个族的正、逆相邻】：
%                          A1..A4, Am1..Am4, D1..D4, Dm1..Dm4,
%                          V1..V4, Vm1..Vm4, H1..H4, Hm1..Hm4,
%                          T_rate, T_reverse_rate
%                        注意不是"先所有正反应、再所有逆反应"，
%                        那样写会让 10x10 矩阵的列整块错位（已踩过此坑）。
%     spec.thermoOutput  热力学速率在输出 CSV 中的插入顺序（A/D 交错）
%     spec.electroOutput 电化学速率在输出 CSV 中的插入顺序（V/H 交错）

    grouped = {};
    for fam = {'A', 'D', 'V', 'H'}
        for i = 1:4
            grouped{end+1} = sprintf('%s%d', fam{1}, i);    %#ok<AGROW>
        end
        for i = 1:4
            grouped{end+1} = sprintf('%sm%d', fam{1}, i);   %#ok<AGROW>
        end
    end
    grouped{end+1} = 'T_rate';
    grouped{end+1} = 'T_reverse_rate';

    thermoOutput = {};
    for fam = {'A', 'D'}
        for i = 1:4
            thermoOutput{end+1} = sprintf('%s%d', fam{1}, i);   %#ok<AGROW>
            thermoOutput{end+1} = sprintf('%sm%d', fam{1}, i);  %#ok<AGROW>
        end
    end
    thermoOutput{end+1} = 'T_rate';
    thermoOutput{end+1} = 'T_reverse_rate';

    electroOutput = {};
    for fam = {'V', 'H'}
        for i = 1:4
            electroOutput{end+1} = sprintf('%s%d', fam{1}, i);  %#ok<AGROW>
            electroOutput{end+1} = sprintf('%sm%d', fam{1}, i); %#ok<AGROW>
        end
    end

    spec = struct('grouped', {grouped}, ...
                  'thermoOutput', {thermoOutput}, ...
                  'electroOutput', {electroOutput});
end
