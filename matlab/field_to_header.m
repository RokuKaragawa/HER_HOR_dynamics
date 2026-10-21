function header = field_to_header(field)
%FIELD_TO_HEADER  把 MATLAB 字段名还原成 Python 版输出 CSV 的列名
%   'Am1' -> 'A-1'，'Dm4' -> 'D-4'，'T_rate' 等保持原样。
%   输入列（case_id / GA1 / a_H ...）不匹配该模式，原样返回。

    switch field
        case {'T_rate', 'T_reverse_rate'}
            header = field;
            return;
    end
    header = regexprep(field, '^([ADVH])m(\d)$', '$1-$2');
end
