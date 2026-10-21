function x = solve_coverages(params, precision)
%SOLVE_COVERAGES  求解 10 个中间体覆盖度的稳态线性方程组
%   对应 Python calculator.py 中的 solve_coverages。
%
%   x = solve_coverages(params)
%   x = solve_coverages(params, 'vpa')     默认，60 位有效数字（等价于 Python 的 Decimal(prec=60)）
%   x = solve_coverages(params, 'double')  双精度快速模式，用 \ 求解，快得多
%
%   params 为 34 个速率常数，顺序（分组）：
%     A1..A4, A-1..A-4, D1..D4, D-1..D-4,
%     V1..V4, V-1..V-4, H1..H4, H-1..H-4, T_rate, T_reverse_rate
%
%   返回归一化后的覆盖度列向量（10x1，和为 1）。
%
%   为什么默认用高精度：速率常数跨越十几个数量级，双精度下矩阵病态，
%   覆盖度可能出现微小负值而触发「负覆盖度」错误。Python 版用 Decimal 60 位正是为此。

    if nargin < 2
        precision = 'vpa';
    end

    params = double(params(:));
    if numel(params) ~= 34
        error('solve_coverages:badCount', 'Expected 34 rate constants, got %d', numel(params));
    end

    switch lower(precision)
        case 'vpa'
            x = solve_high_precision(params);
        case 'double'
            x = solve_double_precision(params);
        otherwise
            error('solve_coverages:badPrecision', 'precision must be ''vpa'' or ''double''');
    end
end


% ---------------------------------------------------------------- 高精度路径
function x = solve_high_precision(params)
    oldDigits = digits;
    digits(60);
    cleanup = onCleanup(@() digits(oldDigits));   %#ok<NASGU>

    % sym(...,'d') 取双精度的十进制最短表示，与 Python 的 Decimal(str(float(v))) 对齐
    p = vpa(sym(params, 'd'));

    a = p(1:8);    % A1..A4, A-1..A-4
    d = p(9:16);   % D1..D4, D-1..D-4
    v = p(17:24);  % V1..V4, V-1..V-4
    h = p(25:32);  % H1..H4, H-1..H-4
    t1 = p(33);    % T_rate
    t2 = p(34);    % T_reverse_rate

    M   = vpa(zeros(10, 10));
    rhs = vpa(zeros(10, 1));

    M(1, :) = 1;   rhs(1) = 1;                                   % 归一化条件 sum(x) = 1
    M(2,1) = a(1); M(2,2) = -(a(5)+a(2)+v(1)+d(6)); M(2,3) = v(5); M(2,5) = a(6); M(2,7) = d(2);
    M(3,2) = v(1); M(3,3) = -(a(3)+v(5)+h(1)+d(7)); M(3,4) = h(5); M(3,6) = a(7); M(3,9) = d(3);
    M(4,1) = d(5); M(4,3) = h(1); M(4,4) = -(a(4)+h(5)+t2+d(1)+d(8));
    M(4,7) = a(8); M(4,8) = t1;   M(4,10) = d(4);
    M(5,2) = a(2); M(5,5) = -(a(6)+v(2));           M(5,6) = v(6);
    M(6,3) = a(3); M(6,5) = v(2); M(6,6) = -(a(7)+v(6)+v(3)+h(2)); M(6,7) = h(6); M(6,8) = v(7);
    M(7,2) = d(6); M(7,4) = a(4); M(7,6) = h(2); M(7,7) = -(a(8)+v(4)+h(6)+d(2)); M(7,9) = v(8);
    M(8,4) = t2;   M(8,6) = v(3); M(8,8) = -(v(7)+h(3)+t1);        M(8,9) = h(7);
    M(9,3) = d(7); M(9,7) = v(4); M(9,8) = h(3); M(9,9) = -(v(8)+h(7)+h(4)+d(3)); M(9,10) = h(8);
    M(10,4) = d(8); M(10,9) = h(4); M(10,10) = -(h(8)+d(4));

    n = 10;
    aug = [M, rhs];

    % 部分主元高斯消元
    for col = 1:n
        [~, offset] = max(abs(aug(col:n, col)));
        pivot = col + offset - 1;
        if aug(pivot, col) == 0
            error('solve_coverages:singular', 'Steady-state matrix is singular');
        end
        if pivot ~= col
            aug([col pivot], :) = aug([pivot col], :);
        end
        for row = col+1:n
            factor = aug(row, col) / aug(col, col);
            aug(row, col+1:n+1) = aug(row, col+1:n+1) - factor * aug(col, col+1:n+1);
            aug(row, col) = 0;
        end
    end

    % 回代
    coverages = vpa(zeros(n, 1));
    for row = n:-1:1
        remainder = aug(row, n+1);
        for j = row+1:n
            remainder = remainder - aug(row, j) * coverages(j);
        end
        coverages(row) = remainder / aug(row, row);
    end

    if any(coverages < 0)
        error('solve_coverages:negative', 'Steady-state solution contains negative coverage');
    end
    total = sum(coverages);
    if total <= 0
        error('solve_coverages:nonPositive', 'Steady-state solution has a non-positive sum');
    end

    x = double(coverages ./ total);
end


% ---------------------------------------------------------------- 双精度路径
function x = solve_double_precision(params)
    a = params(1:8);    d = params(9:16);
    v = params(17:24);  h = params(25:32);
    t1 = params(33);    t2 = params(34);

    M   = zeros(10, 10);
    rhs = zeros(10, 1);

    M(1, :) = 1;   rhs(1) = 1;
    M(2,1) = a(1); M(2,2) = -(a(5)+a(2)+v(1)+d(6)); M(2,3) = v(5); M(2,5) = a(6); M(2,7) = d(2);
    M(3,2) = v(1); M(3,3) = -(a(3)+v(5)+h(1)+d(7)); M(3,4) = h(5); M(3,6) = a(7); M(3,9) = d(3);
    M(4,1) = d(5); M(4,3) = h(1); M(4,4) = -(a(4)+h(5)+t2+d(1)+d(8));
    M(4,7) = a(8); M(4,8) = t1;   M(4,10) = d(4);
    M(5,2) = a(2); M(5,5) = -(a(6)+v(2));           M(5,6) = v(6);
    M(6,3) = a(3); M(6,5) = v(2); M(6,6) = -(a(7)+v(6)+v(3)+h(2)); M(6,7) = h(6); M(6,8) = v(7);
    M(7,2) = d(6); M(7,4) = a(4); M(7,6) = h(2); M(7,7) = -(a(8)+v(4)+h(6)+d(2)); M(7,9) = v(8);
    M(8,4) = t2;   M(8,6) = v(3); M(8,8) = -(v(7)+h(3)+t1);        M(8,9) = h(7);
    M(9,3) = d(7); M(9,7) = v(4); M(9,8) = h(3); M(9,9) = -(v(8)+h(7)+h(4)+d(3)); M(9,10) = h(8);
    M(10,4) = d(8); M(10,9) = h(4); M(10,10) = -(h(8)+d(4));

    if any(~isfinite(M(:)))
        error('solve_coverages:singular', 'Steady-state matrix is singular');
    end

    coverages = M \ rhs;
    if any(coverages < 0)
        error('solve_coverages:negative', 'Steady-state solution contains negative coverage');
    end
    total = sum(coverages);
    if total <= 0
        error('solve_coverages:nonPositive', 'Steady-state solution has a non-positive sum');
    end
    x = coverages ./ total;
end
