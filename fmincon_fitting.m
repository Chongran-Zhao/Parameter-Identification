clc; clear; close all;

% loading data
Treloar_UT_strain = importdata("./Treloar-UT/strain.txt");
Treloar_UT_stress = importdata("./Treloar-UT/stress.txt");

Treloar_ET_strain = importdata("./Treloar-ET/strain.txt");
Treloar_ET_stress = importdata("./Treloar-ET/stress.txt");

Treloar_PS_strain = importdata("./Treloar-PS/strain.txt");
Treloar_PS_stress = importdata("./Treloar-PS/stress.txt");
Model_name = 'CR Model';

[paras, UT, ET, PS] = curve_fitting(Model_name, ...
                                    Treloar_UT_strain, Treloar_UT_stress, ...
                                    Treloar_ET_strain, Treloar_ET_stress, ...
                                    Treloar_PS_strain, Treloar_PS_stress);

UT_x = linspace(1.0, max(Treloar_UT_strain), 25);
ET_x = linspace(1.0, max(Treloar_ET_strain), 25);
PS_x = linspace(1.0, max(Treloar_PS_strain), 25);

figure;
hold on;

plot(Treloar_UT_strain, Treloar_UT_stress, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 8); 
plot(UT_x, UT(paras, UT_x), 'Color', [0.7, 0.7, 0.7], 'LineWidth', 2, 'LineStyle', '-');

plot(Treloar_ET_strain, Treloar_ET_stress, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8); 
plot(ET_x, ET(paras, ET_x), 'Color', [0.85, 0.33, 0], 'LineWidth', 2); % 橙色

plot(Treloar_PS_strain, Treloar_PS_stress, 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8); 
plot(PS_x, PS(paras, PS_x), 'Color', [0, 0.5, 0.5], 'LineWidth', 2); % 青色

hold off;
grid off;

format long
disp('Fitted Parameters:');
for i = 1:numel(paras)-3
    fprintf('Parameter %d: %.6e\n', i, paras(i));
end

for i = numel(paras)-2:numel(paras)
    fprintf('Weight %d: %.6e\n', 3-numel(paras)+i, paras(i));
end

legend('UT of experimental data', ['UT fitted by ', Model_name],...
    'ET of experimental data', ['ET fitted by ', Model_name],...
    'PS of experimental data', ['PS fitted by ', Model_name],...
    'Location', 'NorthWest', 'FontSize', 14);

title('Data and Fitted Curves', 'FontSize', 14);
xlabel('Stretch', 'FontSize', 12);
ylabel('P_{11} of 1st PK stress', 'FontSize', 12);

% Curve fitting function
function [paras, UT, ET, PS] = curve_fitting(Model_name, ...
                                             UT_strain, UT_stress, ...
                                             ET_strain, ET_stress, ...
                                             PS_strain, PS_stress)
switch Model_name
    case 'Ogden Model'
        [paras_0, lb, ub, UT, ET, PS] = Ogden_Model_Init();
    case 'Ogden4 Model'
        [paras_0, lb, ub, UT, ET, PS] = Ogden4_Model_Init();
    case 'CR Model'
        [paras_0, lb, ub, UT, ET, PS] = CR_Model_Init();
    case 'CR4 Model'
        [paras_0, lb, ub, UT, ET, PS] = CR4_Model_Init();
    case 'AB Model'
        [paras_0, lb, ub, UT, ET, PS] = AB_Model_Init();
    case 'MR Model'
        [paras_0, lb, ub, UT, ET, PS] = MR_Model_Init();
    otherwise
        error('ERROR: WRONG INPUT MODEL_NAME!');
end

objectiveFunction = @(x) objective(x, UT_strain, UT_stress, ET_strain, ET_stress, PS_strain, PS_stress, UT, ET, PS);

nonlcon = @(x) nonlcon_func(x);

lb = [lb, 0, 0, 0];
ub = [ub, 1, 1, 1];

options = optimoptions('fmincon', 'Algorithm', 'interior-point', 'MaxIterations', 4000);
paras = fmincon(objectiveFunction, [paras_0, 1/3, 1/3, 1/3], [], [], [], [], lb, ub, nonlcon, options);
resnorm = res(paras, UT_strain, UT_stress, ET_strain, ET_stress, PS_strain, PS_stress, UT, ET, PS);
disp(['Residual norm = ' num2str(resnorm)]);

end

% Objective function
function f = objective(x, UT_strain, UT_stress, ET_strain, ET_stress, PS_strain, PS_stress, UT, ET, PS)
    paras = x(1:end-3);
    weights = x(end-2:end);
    
    res_UT = UT(paras, UT_strain) - UT_stress;
    res_ET = ET(paras, ET_strain) - ET_stress;
    res_PS = PS(paras, PS_strain) - PS_stress;
    
    f = weights(1) * sum(res_UT.^2) + ...
        weights(2) * sum(res_ET.^2) + ...
        weights(3) * sum(res_PS.^2) ;
end

function f = res(paras, UT_strain, UT_stress, ET_strain, ET_stress, PS_strain, PS_stress, UT, ET, PS)    
    res_UT = UT(paras, UT_strain) - UT_stress;
    res_ET = ET(paras, ET_strain) - ET_stress;
    res_PS = PS(paras, PS_strain) - PS_stress;
    
    f = sum(res_UT.^2) + ...
        sum(res_ET.^2) + ...
        sum(res_PS.^2);
end

% Nonlinear constraint function
function [c, ceq] = nonlcon_func(x)
    weights = x(end-2:end);
    c = [];
    ceq = sum(weights) - 1; % Ensure the sum of weights is 1
end

% Initialize CR Model
function [paras_0, lb, ub, UT, ET, PS] = CR_Model_Init()
lb = [-Inf, -Inf, 0, -Inf, -Inf, 0];
ub = [Inf, Inf, Inf, Inf, Inf, Inf];
paras_0 = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0];

% tool function for generalized strain
term1 = @(x, xdata) 2*x(3)*(xdata.^x(2) - xdata.^(-x(1))) .* ((x(2).*(xdata.^(x(2)-1)) + x(1).*(xdata.^(-x(1)-1)) )  / (x(2)+x(1)).^2);
term2 = @(x, xdata) 2*x(6)*(xdata.^x(5) - xdata.^(-x(4))) .* ((x(5).*(xdata.^(x(5)-1)) + x(4).*(xdata.^(-x(4)-1)) )  / (x(5)+x(4)).^2);

% P_11 of generalized strain
UT = @(x, xdata) term1(x, xdata) + term2(x, xdata) - (xdata.^(-1.5)) .* ( term1(x, xdata.^(-0.5)) + term2(x, xdata.^(-0.5)) );
ET = @(x, xdata) term1(x, xdata) + term2(x, xdata) - (xdata.^(-3.0)) .* ( term1(x, xdata.^(-2.0)) + term2(x, xdata.^(-2.0)) );
PS = @(x, xdata) term1(x, xdata) + term2(x, xdata) - (xdata.^(-2.0)) .* ( term1(x, xdata.^(-1.0)) + term2(x, xdata.^(-1.0)) );
end

% Initialize CR4 Model (4 parameters)
function [paras_0, lb, ub, UT, ET, PS] = CR4_Model_Init()
lb = [-Inf, -Inf, 0, 0];
ub = [Inf, Inf, Inf, Inf];
paras_0 = [1.0, 2.0, 4, 1.0];

% tool function for generalized strain
term1 = @(x, xdata) 2*x(3)*(xdata.^x(2) - xdata.^(-x(1))) .* ((x(2).*(xdata.^(x(2)-1)) + x(1).*(xdata.^(-x(1)-1)) )  / (x(2)+x(1)).^2);
term2 = @(x, xdata) 2*x(4).*log(xdata)./xdata;

% P_11 of generalized strain
UT = @(x, xdata) term1(x, xdata) + term2(x, xdata) - (xdata.^(-1.5)) .* ( term1(x, xdata.^(-0.5)) + term2(x, xdata.^(-0.5)) );
ET = @(x, xdata) term1(x, xdata) + term2(x, xdata) - (xdata.^(-3.0)) .* ( term1(x, xdata.^(-2.0)) + term2(x, xdata.^(-2.0)) );
PS = @(x, xdata) term1(x, xdata) + term2(x, xdata) - (xdata.^(-2.0)) .* ( term1(x, xdata.^(-1.0)) + term2(x, xdata.^(-1.0)) );
end

% Initialize Ogden Model
function [paras_0, lb, ub, UT, ET, PS] = Ogden_Model_Init()
lb = [-Inf, -Inf, -Inf, -Inf, -Inf, -Inf];
ub = [Inf, Inf, Inf, Inf, Inf, Inf];
paras_0 = [1.0, 1.0, 1.0, 2.0, -1.0, -1.0];

UT = @(x, xdata) x(1) * ( xdata .^ (x(2) - 1.0) - xdata .^ (-0.5 * x(2) - 1.0) ) ...
    + x(3) * ( xdata .^ (x(4) - 1.0) - xdata .^ (-0.5 * x(4) - 1.0) )...
    + x(5) * ( xdata .^ (x(6) - 1.0) - xdata .^ (-0.5 * x(6) - 1.0) );

ET = @(x, xdata) x(1) * ( xdata .^ (x(2) - 1.0) - xdata .^ (-2.0 * x(2) - 1.0) ) ...
    + x(3) * ( xdata .^ (x(4) - 1.0) - xdata .^ (-2.0 * x(4) - 1.0) )...
    + x(5) * ( xdata .^ (x(6) - 1.0) - xdata .^ (-2.0 * x(6) - 1.0) );

PS = @(x, xdata) x(1) * ( xdata .^ (x(2) - 1.0) - xdata .^ (-1.0 * x(2) - 1.0) ) ...
    + x(3) * ( xdata .^ (x(4) - 1.0) - xdata .^ (-1.0 * x(4) - 1.0) )...
    + x(5) * ( xdata .^ (x(6) - 1.0) - xdata .^ (-1.0 * x(6) - 1.0) );
end

% Initialize Ogden Model (4 parameters)
function [paras_0, lb, ub, UT, ET, PS] = Ogden4_Model_Init()
lb = [-Inf, -Inf, -Inf, -Inf];
ub = [Inf, Inf, Inf, Inf];
paras_0 = [1.0, 1.0, -2.0, -3.0];

UT = @(x, xdata) x(1) * ( xdata .^ (x(2) - 1.0) - xdata .^ (-0.5 * x(2) - 1.0) ) ...
    + x(3) * ( xdata .^ (x(4) - 1.0) - xdata .^ (-0.5 * x(4) - 1.0) );

ET = @(x, xdata) x(1) * ( xdata .^ (x(2) - 1.0) - xdata .^ (-2.0 * x(2) - 1.0) ) ...
    + x(3) * ( xdata .^ (x(4) - 1.0) - xdata .^ (-2.0 * x(4) - 1.0) );

PS = @(x, xdata) x(1) * ( xdata .^ (x(2) - 1.0) - xdata .^ (-1.0 * x(2) - 1.0) ) ...
    + x(3) * ( xdata .^ (x(4) - 1.0) - xdata .^ (-1.0 * x(4) - 1.0) );
end

% Initialize AB Model
function [paras_0, lb, ub, UT, ET, PS] = AB_Model_Init()
lb = [0, 0];
ub = [Inf, Inf];
paras_0 = [1.0, 24.5];

UT = @(x, xdata) x(1) .* ( xdata - xdata.^(-2.0) ) .* ( ...
    1 + ( 1.0 ./ ( 5.0 .* x(2) ) ) .* ( xdata.^2 + 2.0.*(xdata.^(-1)) )...
    + ( 33.0 ./ ( 525.0 .* x(2).^2 ) )  .* ( xdata.^2 + 2.0.*(xdata.^(-1)) ).^2 ...
    + ( 76.0 ./ ( 3500.0 .* x(2).^3 ) ) .* ( xdata.^2 + 2.0.*(xdata.^(-1)) ).^3 ...
    + ( 2595.0 ./ ( 336875.0 .* x(2).^4 ) ) .* ( xdata.^2 + 2.0.*(xdata.^(-1)) ).^4 );

ET = @(x, xdata) x(1) .* ( xdata - xdata.^(-5.0) ) .* ( ...
    1 + ( 1.0 ./ ( 5.0 .* x(2) ) ) .* ( 2.*(xdata.^2) + xdata.^(-4) )...
    + ( 33.0 ./ ( 525.0 .* x(2).^2 ) )  .* ( 2.*(xdata.^2) + xdata.^(-4) ).^2 ...
    + ( 76.0 ./ ( 3500.0 .* x(2).^3 ) ) .* ( 2.*(xdata.^2) + xdata.^(-4) ).^3 ...
    + ( 2595.0 ./ ( 336875.0 .* x(2).^4 ) ) .* ( 2.*(xdata.^2) + xdata.^(-4) ).^4 );

PS = @(x, xdata) x(1) .* ( xdata - xdata.^(-3.0) ) .* ( ...
    1 + ( 1.0 ./ ( 5.0 .* x(2) ) ) .* ( xdata.^2 + xdata.^(-2) + 1 )...
    + ( 33.0 ./ ( 525.0 .* x(2).^2 ) )  .* ( xdata.^2 + xdata.^(-2) + 1 ).^2 ...
    + ( 76.0 ./ ( 3500.0 .* x(2).^3 ) ) .* ( xdata.^2 + xdata.^(-2) + 1 ).^3 ...
    + ( 2595.0 ./ ( 336875.0 .* x(2).^4 ) ) .* ( xdata.^2 + xdata.^(-2) + 1 ).^4 );
end

% Initialize MR Model
function [paras_0, lb, ub, UT, ET, PS] = MR_Model_Init()
lb = [0, 0];
ub = [Inf, Inf];
paras_0 = [1, 1];

UT = @(x, xdata) 2.0 .* ( x(1) + x(2)./xdata ) .* ( xdata - xdata.^(-2));
ET = @(x, xdata) 2.0 .* ( x(1) + x(2) .* xdata.^2 ) .* (xdata - xdata.^(-5));
PS = @(x, xdata) 2.0 .* ( x(1) + x(2) ) .* ( xdata - xdata.^(-3));
end