function [x0, u0, lib] = FindTrimDrake(p, lib, gains)
    %% find fixed point
    
    initial_guess = [0; 12; 0; 0; p.umax(3)];
    
    
    disp('Searching for fixed point...');
    
    prog = NonlinearProgram(5);

    func = @(in) tbsc_model_less_vars(in(1:2), in(3:5), p.parameters);


    % min_xdot = 5;
    % max_xdot = 30;
    % 
    % min_pitch = -1;
    % max_pitch = 1;



    c = FunctionHandleConstraint( zeros(6,1), zeros(6,1), 5, func);
    c.grad_method = 'numerical';
    prog = prog.addConstraint(c);
    
    
    
    c_input_limits = BoundingBoxConstraint([-Inf; -Inf; p.umin], [Inf; Inf; p.umax]);
    
    prog = prog.addConstraint(c_input_limits);

    %c2 = BoundingBoxConstraint( [ 0.1; 10; -.5; -.5; 0 ], [1; 30; .5; .5; 4] );

    %p = p.addConstraint(c2);

tic
    [x, objval, exitflag] = prog.solve( initial_guess );
toc


    
    assert(exitflag == 1, ['Solver error: ' num2str(exitflag)]);

    

    %full_state = zeros(12,1);

    %full_state(5) = x(1);
    %full_state(7) = x(2);

    %p.dynamics(0, full_state, x(3:5));

    x0 = zeros(12, 1);
    x0(5) = x(1);
    x0(7) = x(2);

    x0 = ConvertDrakeFrameToEstimatorFrame(x0);
    
    u0 = zeros(3,1);

    u0(1) = x(3);
    u0(2) = x(4);
    u0(3) = x(5);
    
    disp('Fixed point found:');

    disp('x0:')
    disp(x0');

    disp('u0:')
    disp(u0');


    %% build lqr controller based on that trim


    % I'd like to get Q and R tuned to give something close to APM's nominal
    % PID values (omitting I since LQR can't do that)
    %
    % Roll:
    %   P: 0.4
    %   I: 0.04
    %   D: 0.02
    %
    % Pitch:
    %   P: 0.4
    %   I: 0.04
    %   D: 0.02
    %
    % Yaw:
    %   P: 1.0
    %   I: 0
    %   D: 0



% WORKING WELL 09/03/2015
%     Q = diag([0 0 0 10 30 .25 0.1 .0001 0.0001 .001 .001 .1]);
%     Q(1,1) = 1e-10; % ignore x-position
%     Q(2,2) = 1e-10; % ignore y-position
%     Q(3,3) = 1e-10; % ignore z-position


    %R = diag([35 35 35]);
    %R_values = [35 50 25];

    [A, B, C, D, xdot0, y0] = p.linearize(0, x0, u0);
    %% check linearization

    %(A*(x0-x0) + B*(u0-u0) + xdot0) - p.dynamics(0, x0, u0)

    %(A*.1*ones(12,1) + B*.1*ones(3,1) + xdot0) - p.dynamics(0, x0+.1*ones(12,1), u0+.1*ones(3,1))

    %% add a bunch of controllers

    lib = AddTiqrControllers(lib, 'TI-straight', A, B, x0, u0, gains);
end
