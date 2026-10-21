function y = logaddexp0(z)
%LOGADDEXP0  数值稳定的 ln(1 + exp(z))
%   对应 Python 的 np.logaddexp(0.0, z)。
%
%   直接用 log(1+exp(z)) 在 z 很大时会溢出，z 很小时会丢精度。
%   等价变形： ln(1+e^z) = max(z,0) + ln(1 + e^(-|z|))
%   其中 ln(1+t) 用 log1p 计算以保留小量精度。

    y = max(z, 0) + log1p(exp(-abs(z)));
end
