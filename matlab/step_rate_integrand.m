function value = step_rate_integrand(x, drive, reorganization, kbt, reverse, base)
%STEP_RATE_INTEGRAND  单步电子转移速率的被积函数
%   对应 Python calculator.py 中的 step_rate_integrand。
%
%   被积函数 = exp( -(drive_sign*drive + x_sign*x + lambda)^2 / (4*lambda*kBT)
%                   - ln(1 + exp(thermal_coordinate)) )
%
%   输入：
%     x              积分变量
%     drive          驱动力（已含 eta、pH 项，base 情形另含 water_energy）
%     reorganization 重组能 lambda
%     kbt            k_B * T
%     reverse        是否为逆反应
%     base           是否为碱性（氢氧化）通道

    if reverse
        drive_sign = -1.0;
        x_sign     =  1.0;
    else
        drive_sign =  1.0;
        x_sign     = -1.0;
    end

    numerator = drive_sign .* drive + x_sign .* x + reorganization;

    % 注意：只有「逆反应 且 碱性通道」才取 -x/kbt
    if reverse && base
        thermal_coordinate = -x ./ kbt;
    else
        thermal_coordinate =  x ./ kbt;
    end

    exponent = -(numerator .^ 2) ./ (4.0 .* reorganization .* kbt);
    value = exp(exponent - logaddexp0(thermal_coordinate));
end
