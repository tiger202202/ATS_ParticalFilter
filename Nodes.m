classdef Nodes
    % 这是一个包括所有节点的系统，记录了各个节点
    % 使用这种设计模式，可以方便的管理海量节点（如果需要的话，可以继续扩展，包括自动生成随机节点）
    
    properties
        nodes
        S_ioj
        config
        config_partical_filter
    end
    
    methods
        function obj = Nodes(config, config_partical_filter)
            
            obj.config = config;
            obj.config_partical_filter = config_partical_filter;
            
            % 可以自动生成大规模分布式节点（无需手动定义），如果需要的话
            if 0
                
                num_particle = 100;
                
                % 创建节点
                for node_id = 1:num_particle
                    
                    param1 = randn(1) + 3.5;  % 2~5
                    param2 = randn(1) + 0.7;  % 0.2~1.2
                    
                    obj.nodes = [obj.nodes; Node(node_id, param1, param2, config)];
                    
                    % 与前一个节点连接
                    if node_id > 1
                        obj = obj.create_relationship(node_id - 1, node_id);
                    end
                end
                
                % 创建随机连接
                for i_times = 1:sqrt(num_particle)*num_particle
                    
                    node_id_1 = randi(num_particle);
                    node_id_2 = node_id_1;
                    
                    % 直到二者不一样，才可以跳出循环
                    while node_id_1 == node_id_2
                        node_id_2 = randi(num_particle);
                    end
                    
                    % 允许连接重复。例如已经添加过1→2，还可以再次添加1→2。因为在现实中，允许这种路由方式。
                    obj = obj.create_relationship(node_id_1, node_id_2);
                end
                
            end
            
            % 使用实验方案中的拓扑图
            if 0
                % 创建节点
                obj.nodes = [obj.nodes; Node(1, 2, 0.2, config)];
                obj.nodes = [obj.nodes; Node(2, 5, 0.3, config)];
                obj.nodes = [obj.nodes; Node(3, 3, 0.5, config)];
                obj.nodes = [obj.nodes; Node(4, 2.3, 1.2, config)];
                obj.nodes = [obj.nodes; Node(5, 4, 0.8, config)];
                obj.nodes = [obj.nodes; Node(6, 3.2, 0.7, config)];
                obj.nodes = [obj.nodes; Node(7, 4.4, 1.1, config)];
                obj.nodes = [obj.nodes; Node(8, 2.7, 0.6, config)];
                obj.nodes = [obj.nodes; Node(9, 4.1, 0.4, config)];
                obj.nodes = [obj.nodes; Node(10, 2.6, 1.0, config)];
                
                % 建立节点间关系
                obj = obj.create_relationship(1, 2);
                obj = obj.create_relationship(2, 3);
                obj = obj.create_relationship(3, 4);
                obj = obj.create_relationship(4, 5);
                obj = obj.create_relationship(5, 6);
                obj = obj.create_relationship(6, 7);
                obj = obj.create_relationship(7, 8);
                obj = obj.create_relationship(8, 9);
                obj = obj.create_relationship(1, 8);
                obj = obj.create_relationship(3, 9);
                obj = obj.create_relationship(4, 9);
                obj = obj.create_relationship(6, 10);
            end
            
            % 原始代码的数据
            if 1
                obj.nodes = [obj.nodes; Node(1, 2, 0.2, config)];
                obj.nodes = [obj.nodes; Node(2, 5, 0.3, config)];
                obj.nodes = [obj.nodes; Node(3, 3, 0.5, config)];
                obj.nodes = [obj.nodes; Node(4, 2.3, 1.2, config)];

                obj = obj.create_relationship(1, 2);
                obj = obj.create_relationship(2, 3);
                obj = obj.create_relationship(3, 4);
            end
            
            obj = obj.init_Sioj();
        end
        
        function obj = create_relationship(obj,node1, node2)
            % 创建两个节点的关系
            
            obj.nodes(node1) = obj.nodes(node1).to(node2);
            obj.nodes(node2) = obj.nodes(node2).from(node1);
            
            obj.nodes(node2) = obj.nodes(node2).to(node1);
            obj.nodes(node1) = obj.nodes(node1).from(node2);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%ATS
        
        function obj = init_Sioj(obj)
            
            num_nodes = size(obj.nodes, 1);
            
            obj.S_ioj = zeros(num_nodes, num_nodes);
            
            for i_node = 1:num_nodes
                current_node = obj.nodes(i_node);
                
                nodes_from = current_node.nodes_from;
                num_nodes_from = size(nodes_from, 1);
                
                t1 = current_node.t1;
                
                for i_node_from = 1:num_nodes_from
                    node_from = nodes_from(i_node_from);
                    t2 = obj.nodes(node_from).t1;
                    obj.S_ioj(i_node, node_from) = (t1(4)-t1(4-1)) / (t2(4)-t2(4-1));
                end
            end
        end
        
        function obj = update_SRC(obj, i)
            
            p = obj.config.p;
            
            num_nodes = size(obj.nodes, 1);
            for i_node = 1:num_nodes                
                current_node = obj.nodes(i_node);
                
                nodes_from = current_node.nodes_from;
                num_nodes_from = size(nodes_from, 1);
                
                t1 = current_node.t1;
                
				% 记录 S_ioj，供下次使用
                for i_node_from = 1:num_nodes_from
                    node_from = nodes_from(i_node_from);
                    obj.S_ioj(i_node, node_from) = obj.nodes(i_node).S_ioj_out(i_node_from);
                end

                % 用所有邻居节点的信息更新此节点
                R1_change = mean(obj.nodes(i_node).R1_change);
                c_change = mean(obj.nodes(i_node).c_change);


                obj.nodes(i_node).R_1 = ...
                    p * obj.nodes(i_node).R_1 + ...
                    (1-p) * R1_change;    %虚拟时钟斜率计算

                c_delta = ...
                    c_change - ...
                    obj.nodes(i_node).R_1 * t1(i) - obj.nodes(i_node).c1;
					
                obj.nodes(i_node).c1 = obj.nodes(i_node).c1 + (1-p) * c_delta;          %虚拟时钟相位计算
				
            end            
        end
        
        function obj = update_ac(obj, i)
            
            num_nodes = size(obj.nodes, 1);
            for i_node = 1:num_nodes
                
                current_node = obj.nodes(i_node);                
    
                obj.nodes(i_node).a11(i) = current_node.a1 * current_node.R_1;
                obj.nodes(i_node).c11(i) = current_node.c1 + current_node.R_1 * current_node.b1;
                
            end            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%画图
        
        function obj = plot_a11(obj)
            
            num_nodes = size(obj.nodes, 1);      
            
            for i_node = 1:num_nodes
                current_node = obj.nodes(i_node);   
                
                plot(current_node.a11);
                hold on
            end
            
            axis([4 inf -inf inf]);       
        end
        
        function obj = plot_error(obj)
            
            A = [];
            
            num_nodes = size(obj.nodes, 1);      
            
            for i_node = 1:num_nodes
                current_node = obj.nodes(i_node);   
                A = [A, current_node.a11];
            end
            
            S=std(A,0,2);      
            figure
            plot(S,'-');
            axis([4 inf -inf inf]);
        end
        
        function obj = plot_c11(obj)
            
            figure
            
            num_nodes = size(obj.nodes, 1);      
            
            for i_node = 1:num_nodes
                current_node = obj.nodes(i_node);   
                
                plot(current_node.c11);
                hold on
            end
            
            axis([4 inf -inf inf]);       
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%粒子滤波
        
        % 粒子滤波初始化
        function obj = partical_filter_init(obj, config_partical_filter)
            
            num_nodes = size(obj.nodes, 1);
            
            for i_node=1:num_nodes
            
                obj.nodes(i_node) = obj.nodes(i_node).partical_filter_init(config_partical_filter);   
            end
        end
        
        % 粒子滤波
        function obj = partical_filter(obj, config_partical_filter, i_times)
            
            num_nodes = size(obj.nodes, 1);            
            for i_node=1:num_nodes          
            
                obj.nodes(i_node) = obj.nodes(i_node).partical_filter(config_partical_filter, i_times); 
                
            end
        end
        
        % 粒子滤波
        function obj = add_noise(obj, config_partical_filter, i_times)
            
            num_nodes = size(obj.nodes, 1);            
            for i_node=1:num_nodes          
            
                obj.nodes(i_node) = obj.nodes(i_node).add_noise(config_partical_filter, i_times); 
                
            end
        end
        
        % 获取周围节点的信息
        function obj = get_data(obj, i_times) 
            
            num_nodes = size(obj.nodes, 1);            
            for i_node=1:num_nodes 
                current_node = obj.nodes(i_node);
                
                t1 = current_node.t1;
                
                obj.nodes(i_node).t2_out = [];
                obj.nodes(i_node).relative_slope = [];
                obj.nodes(i_node).S_ioj_out = [];
                obj.nodes(i_node).R1_change = [];
                obj.nodes(i_node).c_change = [];
                
                num_nodes_from = size(obj.nodes(i_node).nodes_from, 1);
                for i_node_from=1:num_nodes_from
                    node_from = obj.nodes(i_node).nodes_from(i_node_from);
                    
                    t2 = obj.nodes(node_from).t1;
                    
                    obj.nodes(i_node).t2_out = [obj.nodes(i_node).t2_out, t2(i_times)];
                    obj.nodes(i_node).relative_slope = [obj.nodes(i_node).relative_slope, ...
                        (t2(i_times)-t2(i_times-1))/(t1(i_times)-t1(i_times-1))];
                    
                end
            end
            
        end
        
        % 获取周围节点的信息
        function obj = update_data(obj, i_times) 
            
            p = obj.config.p;
            
            num_nodes = size(obj.nodes, 1);            
            for i_node=1:num_nodes 
                
                num_nodes_from = size(obj.nodes(i_node).nodes_from, 1);
                for i_node_from=1:num_nodes_from
                    node_from = obj.nodes(i_node).nodes_from(i_node_from);
						
                    obj.nodes(i_node).S_ioj_out = [obj.nodes(i_node).S_ioj_out, ...
                        p * obj.S_ioj(i_node, node_from) + ...
                        (1-p) * obj.nodes(i_node).relative_slope(i_node_from)];
                    
					obj.nodes(i_node).R1_change = [obj.nodes(i_node).R1_change, ...
						obj.nodes(i_node).S_ioj_out(i_node_from) * obj.nodes(node_from).R_1];
                    
					obj.nodes(i_node).c_change = [obj.nodes(i_node).c_change, ...
                        obj.nodes(node_from).R_1 * obj.nodes(i_node).t2_out(i_node_from) + obj.nodes(node_from).c1];
                    
                end
            end            
        end
        
    end
end

