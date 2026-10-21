%% 运行.m  —— MATLAB 版 HER/HOR 计算程序入口
%
%  【怎么用】
%    1. 打开 MATLAB
%    2. 在左侧"当前文件夹"里进入本目录（...\Linear Equation\matlab）
%    3. 双击打开本文件 运行.m
%    4. 按键盘 F5（或点上方的"运行"按钮）
%
%  也可以直接在 MATLAB 命令窗口输入：  运行
%
%  本脚本会自动把所在目录加入搜索路径，不需要手动 addpath。

clc;

% ==================== 把本目录加入搜索路径 ====================
thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);
fprintf('已加入搜索路径：%s\n\n', thisDir);

% ==================== 选择要运行的任务 ====================
%  改下面这个数字即可（1 ~ 8）
TASK = 1;

switch TASK

    case 1
        % 【快速出图】η ∈ [-0.25, 0.25] V，步长 0.005 V，101 点，约 1 分钟
        % 想先看看效果就用这个
        fprintf('任务 1：快速出图（步长 0.005 V，约 1 分钟）\n');
        rH2_eta_curve('etaStep', 0.005);

    case 2
        % 【精细出图】η ∈ [-0.25, 0.25] V，步长 0.001 V，501 点，约 5 分钟
        % 论文用图建议跑这个
        fprintf('任务 2：精细出图（步长 0.001 V，501 点，约 5 分钟）\n');
        rH2_eta_curve('etaStep', 0.001);

    case 3
        % 【最精细】步长 0.0005 V，1001 点，约 9 分钟
        fprintf('任务 3：最精细出图（步长 0.0005 V，1001 点，约 9 分钟）\n');
        rH2_eta_curve('etaStep', 0.0005);

    case 4
        % 【换氢气压】p = 0.1，对应 Python 的 near_equilibrium_sweep.py
        fprintf('任务 4：p = 0.1 精细出图（501 点，约 5 分钟）\n');
        rH2_eta_curve('etaStep', 0.001, 'p', 0.1, 'aH', 1.0);

    case 5
        % 【基线过电位扫描】等价于 Python 的 eta_sweep.py
        % η ∈ [-0.25, 0.305] V，步长 0.005 V
        fprintf('任务 5：基线过电位扫描（等价 eta_sweep.py）\n');
        eta_sweep();

    case 6
        % 【近平衡区扫描】等价于 Python 的 near_equilibrium_sweep.py
        % η ∈ [-0.25, 0.25] V，步长 0.002 V，p = 0.1
        fprintf('任务 6：近平衡区扫描（等价 near_equilibrium_sweep.py）\n');
        near_equilibrium_sweep();

    case 7
        % 【批量计算】只算 CSV 不出图，输入用 Python 那边的模板
        inputCsv  = fullfile(thisDir, '..', 'batch_calculator', 'input_template.csv');
        outputCsv = fullfile(thisDir, 'results_from_template.csv');
        fprintf('任务 7：批量计算 %s\n', inputCsv);
        run_batch(inputCsv, outputCsv);
        fprintf('结果已写入：%s\n', outputCsv);

    case 8
        % 【换自己的参数文件】把下面路径改成你的 CSV
        myCsv = fullfile(thisDir, 'my_input.csv');
        if ~isfile(myCsv)
            error('找不到文件：%s\n请先把参数 CSV 放到该路径，或修改本行。', myCsv);
        end
        fprintf('任务 8：批量计算 %s\n', myCsv);
        run_batch(myCsv, fullfile(thisDir, 'my_results.csv'));

    otherwise
        error('TASK 只能是 1 ~ 8，当前是 %g', TASK);
end

fprintf('\n任务结束。\n');
