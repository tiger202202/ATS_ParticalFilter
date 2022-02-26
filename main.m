
% 当前代码可以直接运行，结果是论文中的拓扑图中多个节点的运行结果。
% 目前的参数，直接继承了原来代码的参数。如有需要，可以根据实验调参。

clc; clear;
close all;

%%

% 参数配置
config.l = 300;
config.t = 0:10^(-5):1;
config.p = 0.5;
config_partical_filter = ConfigParticalFilter();    % 参数较多，放到配置类中
config_partical_filter.M = config.l;                % 噪声的长度要相同

% 节点初始化。使用面向对象的方法，真实描述了各节点的状态，及其每次迭代的过程
nodes = Nodes(config, config_partical_filter);
nodes = nodes.partical_filter_init(config_partical_filter);

% 运行
for i_times = 4:config.l+2
    
    % 各个节点获得相邻节点的状态（此时未更新）
    nodes = nodes.get_data(i_times);
    
    % 添加噪声
    nodes = nodes.add_noise(config_partical_filter, i_times);
    
    % 对获得的信息滤波
    nodes = nodes.partical_filter(config_partical_filter, i_times);
	
    nodes = nodes.update_data(i_times);
    
    % ATS算法更新当前节点状态
    nodes = nodes.update_SRC(i_times);
    nodes = nodes.update_ac(i_times);
    
    disp("Finish: " + i_times);
end

%% 画图
nodes.plot_a11();   % 斜率估计
nodes.plot_error(); % 斜率一致的误差
nodes.plot_c11();   % 相位估计
