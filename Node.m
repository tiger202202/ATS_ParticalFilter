classdef Node
    % 这是对一个节点的描述
    
    properties
        id
        nodes_to
        nodes_from
        
        a11
        c11
        
        a1
        b1
        t1
        R_1
        c1
        
        % 粒子滤波        
        X
        X_forOther
        Z
        Z_forOther

        Xn
        Xn_forOther
            
        % 粒子滤波估计初始化
        Xmean_pf

        % 粒子集初始化
        Xparticle_pf_experiment
        XparticlePred_pf_experiment
        weight_experiment
        ww         
        
        t2_out
        relative_slope
        relative_slope_last     % 上一时刻的，给粒子滤波预测时使用
        S_ioj_out
        R1_change
        c_change
		
		v
    end
    
    methods
        function obj = Node(id, a1, b1, config)
            
            obj.id = id;
            obj.a1 = a1;
            obj.b1 = b1;
            obj.t1 = a1 * config.t + b1;
            obj.R_1 = 1;
            obj.c1 = 0;
        
            obj.a11=zeros(config.l,1);
            obj.c11=zeros(config.l,1);
        end
        
        function obj = to(obj, node)
            
            obj.nodes_to = [obj.nodes_to; node];
        end
        
        function obj = from(obj, node)
            
            obj.nodes_from = [obj.nodes_from; node];
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % 粒子滤波初始化
        function obj = partical_filter_init(obj, config_partical_filter)
            
            % 在每次更新时，记录上一个状态，最终做到同步更新。（假设A→B，B→A。A、B的更新不应分先后。所以上一时刻的A影响B，上一时刻的B影响A）
            obj.X_forOther=zeros(4,config_partical_filter.M);
            obj.Z_forOther=zeros(2,config_partical_filter.M);

            obj.Xn=zeros(2,config_partical_filter.M);
            obj.Xn_forOther=zeros(2,config_partical_filter.M);

            % 粒子集初始化
            obj.Xparticle_pf_experiment=zeros(1,config_partical_filter.M,config_partical_filter.N);
            obj.XparticlePred_pf_experiment=zeros(config_partical_filter.M,config_partical_filter.N);
            obj.weight_experiment=zeros(config_partical_filter.M,config_partical_filter.N);  % 粒子权值
            %初始化
            for i=1:config_partical_filter.N
                obj.Xparticle_pf_experiment(:,1,i)=20*config_partical_filter.my_random.a4(1);
            end
			
            % 均匀噪声。减0.5是，使分布的中心在0
% 			obj.v=sqrtm(config_partical_filter.R) * (rand(1,config_partical_filter.M) - 0.5);		

            % 高斯噪声。高斯分布的均值，本来就在0
			obj.v=sqrtm(config_partical_filter.R) * randn(1,config_partical_filter.M);

            % 指数分布。需要减去2，使分布的中心在0
% 			obj.v=sqrtm(config_partical_filter.R) * (exprnd(2, 1, config_partical_filter.M) - 2);

            % 韦布尔分布。需要减去wblstat(1.5,1.8)，使分布的中心在0
% 			obj.v=sqrtm(config_partical_filter.R) * (wblrnd(1.5, 1.8, 1, config_partical_filter.M) - wblstat(1.5,1.8));

            % 伽马分布。需要减去wblstat(1.5,1.8)，使分布的中心在0
% 			obj.v=sqrtm(config_partical_filter.R) * (gamrnd(1.5, 1.8, 1, config_partical_filter.M) - 1.5 * 1.8);
            
            % 解释一下为什么分布的均值要在0。因为噪声使观测值在真实值上下波动
            % 如果均值大于0，那就代表观测值一定大于真实值，这就不叫随机噪声了，叫错误或者系统误差

%             plot(obj.v);      画出噪声图
            
            obj.relative_slope_last = 0;   % 初始化
        end
        
        function obj = partical_filter(obj, config_partical_filter, i_times)
            
            t = i_times - 2;
            
            R1 = config_partical_filter.R1;
            R2 = config_partical_filter.R2;
            N = config_partical_filter.N;
            eta = config_partical_filter.eta; 
            
            num_neighbor = size(obj.t2_out, 2);
            
            for i_neighbor = 1:num_neighbor
        
				%采样
				for i=1:N                    
                    
                    % 第一次估计时，没有基于上一次的粒子预测。所以直接用观测值
					if t == 2
                        obj.relative_slope_last(i_neighbor) = obj.relative_slope(i_neighbor);
                    end
                    
                    obj.XparticlePred_pf_experiment(t,i) = obj.relative_slope_last(i_neighbor) + 0.012*(rand(1) - 0.5);
				
				end
			   
				%重要性权值计算
				for i=1:N
					
					obj.weight_experiment(t,i) = ...
						(1-eta)*inv(sqrt(2*pi*det(R1))) ...
						*exp( ...
							-.5 * ...
							(obj.relative_slope(i_neighbor)-obj.XparticlePred_pf_experiment(t,i))' * ...
							inv(R1(1)) * ...
							(obj.relative_slope(i_neighbor)-obj.XparticlePred_pf_experiment(t,i)) )...  % 高斯噪声
						+eta*inv(sqrt(2*pi*det(R2))) ...
						*exp(-.5 * (obj.relative_slope(i_neighbor)-obj.XparticlePred_pf_experiment(t,i))' * inv(R2(1)) * (obj.relative_slope(i_neighbor)-obj.XparticlePred_pf_experiment(t,i)))...  % 闪烁噪声
						+ 1e-99;                                % 权值计算，为了避免权值为0，在此加了最小值1e-99
				end
				obj.weight_experiment(t,:)=obj.weight_experiment(t,:)./sum(obj.weight_experiment(t,:));%归一化权值
				
				outIndex = randomR(1:N, obj.weight_experiment(t,:)');                       % random resampling.
				obj.Xparticle_pf_experiment(1,t,:) = obj.XparticlePred_pf_experiment(t, outIndex); % 获取新采样值

				% 状态估计
				obj.relative_slope(i_neighbor)=mean(obj.Xparticle_pf_experiment(1,t,:));
				obj.relative_slope_last = obj.relative_slope;   % 记录，共下次粒子滤波使用
            end
        end
        
        function obj = add_noise(obj, config_partical_filter, i_times)
            
            t = i_times - 2;
            
            num_neighbor = size(obj.t2_out, 2);
            
            for i_neighbor = 1:num_neighbor
			
                % 根据微信的沟通，使用相对时钟斜率计算。
                % 加入噪声。真的随机数，所以每次跑，图表都不一样。
                % 噪声大小定义在这里：ConfigParticalFilter.delta_r = 试试 0.001~0.01
                obj.relative_slope(i_neighbor) = obj.relative_slope(i_neighbor) + obj.v(t);	
            end
        end
    end
end

