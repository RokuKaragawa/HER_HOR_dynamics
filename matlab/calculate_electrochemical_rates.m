function rates = calculate_electrochemical_rates(values, kbt, eta, ph, water_energy, proton_activity, hydroxide_activity, prefactor)
%CALCULATE_ELECTROCHEMICAL_RATES  电化学步骤速率 V/H
%   对应 Python calculator.py 中的 calculate_electrochemical_rates。
%
%   第 1..4 步属于 V 族（Volmer 类），第 5..8 步属于 H 族（Heyrovsky/Tafel 类）。
%   每一步都要算 4 个积分：酸性正/逆、碱性正/逆，再按酸/碱通道加权合成：
%     正反应 fw = 酸性fw * prefactor * a_H + 碱性fw * prefactor
%     逆反应 rv = 酸性rv * prefactor       + 碱性rv * prefactor * a_OH

    rates = struct();
    for step = 1:8
        if step <= 4
            family = 'V';
            number = step;
        else
            family = 'H';
            number = step - 4;
        end

        free_energy    = values.(sprintf('G%s%d', family, number));
        reorganization = values.(sprintf('lambda%s%d', family, number));

        acid_forward = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, false, false);
        acid_reverse = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, true,  false);
        base_forward = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, false, true);
        base_reverse = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, true,  true);

        rates.(sprintf('%s%d',  family, number)) = ...
            acid_forward * prefactor * proton_activity + base_forward * prefactor;
        rates.(sprintf('%sm%d', family, number)) = ...
            acid_reverse * prefactor + base_reverse * prefactor * hydroxide_activity;
    end
end
