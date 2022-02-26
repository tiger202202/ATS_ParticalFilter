classdef ConfigParticalFilter
    
    properties
        M                   %采样点数
        T                   %采样间隔
        N                   %粒子数
        number              %Monte Carlo仿真次数

        delta_r             %发送信号到收到信号，噪声下观测距离标准差
        delta_theta1        %热噪声对应方位角标准差
        delta_theta2        %闪烁效应对应方位角标准差
        eta                 % 此参数控制噪声形式，=0为高斯噪声，非零为闪烁噪声

        R1
        R2

        R
        G
        my_random           % 将随机数保存，这样可以复现实验。需要时，可以打开开关，使用真实随机数。
    end
    
    methods
        function obj = ConfigParticalFilter()
            
            %初始化相关参数
            obj.M=100;                                              %采样点数
            obj.T=1;                                                %采样间隔
            obj.N=100;                                              %粒子数
            obj.number=10;                                          %Monte Carlo仿真次数

            obj.delta_r = 0.003;                                       %噪声下观测标准差
            obj.delta_theta1=1*pi/180;                              %热噪声对应方位角标准差
            obj.delta_theta2=5*pi/180;                              %闪烁效应对应方位角标准差
            obj.eta=0.3;                        % 此参数控制噪声形式，=0为高斯噪声，非零为闪烁噪声

            obj.R1=obj.delta_r^2;
            obj.R2=obj.delta_r^2;

            obj.R= obj.delta_r^2;
            
            % 真实的随机数
            obj.my_random.w = randn(2,obj.M);
            obj.my_random.xmean_pf = randn(4,1);
            obj.my_random.a4 = randn(4,1);
            obj.my_random.a5 = randn(2,obj.M);
            obj.my_random.u=rand(obj.M,1);
        end
    end
end

