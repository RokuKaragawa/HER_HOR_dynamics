function rates = calculate_nonideal_rates(values, delta_g0, kbt, sigma, prefactor)
%CALCULATE_NONIDEAL_RATES  热力学（非理想）速率 A/D/T
%   对应 Python calculator.py 中的 calculate_nonideal_rates。
%
%   9 个自由能：
%     1..4  = GA1..GA4
%     5..8  = delta_g0 - GAi - GVi - GHi
%     9     = delta_g0 - GA3 - GV3，再减去第 5 个（即 free_energies[8] -= free_energies[4]）
%
%   每个自由能给出正/逆两个速率：
%     forward = prefactor * exp( -ln(1+exp( sigma*G)) / (sigma*kBT) )
%     reverse = prefactor * exp( -ln(1+exp(-sigma*G)) / (sigma*kBT) )

    free_energies = zeros(9, 1);
    for i = 1:4
        free_energies(i) = values.(sprintf('GA%d', i));
    end
    for i = 1:4
        free_energies(4 + i) = delta_g0 - values.(sprintf('GA%d', i)) ...
                               - values.(sprintf('GV%d', i)) ...
                               - values.(sprintf('GH%d', i));
    end
    free_energies(9) = delta_g0 - values.GA3 - values.GV3;
    free_energies(9) = free_energies(9) - free_energies(5);

    rates = struct();
    for index = 1:9
        free_energy = free_energies(index);
        forward = prefactor * exp(-logaddexp0( sigma * free_energy) / (sigma * kbt));
        reverse = prefactor * exp(-logaddexp0(-sigma * free_energy) / (sigma * kbt));

        if index <= 4
            rates.(sprintf('A%d',  index)) = forward;
            rates.(sprintf('Am%d', index)) = reverse;
        elseif index <= 8
            rates.(sprintf('D%d',  index - 4)) = forward;
            rates.(sprintf('Dm%d', index - 4)) = reverse;
        else
            rates.T_rate = forward;
            rates.T_reverse_rate = reverse;
        end
    end
end
