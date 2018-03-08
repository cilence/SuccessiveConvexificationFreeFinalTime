function [x, u, s, d] = solve_socp(A, B, C, S, z, X_last, U_last, sigma_last, x_init, x_final, K)

w_nu = 1e5;
w_delta = 1e-3;
w_delta_sigma = 1e-1;

nu_tol = 1e-10;
delta_tol = 1e-3;

gamma_gs = deg2rad(20);
delta_max = deg2rad(20);
theta_max = deg2rad(90);
w_max = deg2rad(60);
m_dry = 1;
T_min = 0.3;
T_max = 5;

disp("Setting up constraints.")
cvx_begin
% -------------------------------------------------------------------------

variable X(K, 14)
variable U(K, 3)
variable sig
variable nu(14 * (K-1))
variable delta(K)
variable delta_s

minimize(sig + w_nu * norm(nu, 1) + w_delta * norm(delta) + w_delta_sigma * norm(delta_s, 1))
subject to

% Boundary conditions:
X(1, 1) == x_init(1);
X(1, 2:4) == x_init(2:4);
X(1, 5:7) == x_init(5:7);
% X(K, 8:11) == x_init(8:11);
X(1, 12:14) == x_init(12:14);

X(K, 2:4) == x_final(2:4);
X(K, 5:7) == x_final(5:7);
X(K, 8:11) ==  x_final(8:11);
X(K, 12:14) ==  x_final(12:14);

U(K, 2) == 0;
U(K, 3) == 0;

% Dynamics:
for k = 1:K-1
    X(k + 1, :)' == squeeze(A(k, :, :)) * X(k, :)' + squeeze(B(k, :, :)) * U(k, :)' + squeeze(C(k, :, :)) * U(k + 1, :)' + S(k, :)' * sig + z(k, :)' + nu(14 * k - 13 : 14 * k)
end

% State constraints:
X(:, 1) >= m_dry;
for k = 1:K
    tan(gamma_gs) * norm(X(k, 3:4)) <= X(k, 2);
    cos(theta_max) <= 1 - 2 * X(k, 10:11) * X(k, 10:11)';
    norm(X(k, 12:14)) <= w_max;
end

% Control constraints:
for k = 1:K
    B_g = U_last(k, :) / norm(U_last(k, :));
    T_min <=  B_g * U(k, :)';
    norm(U(k, :)) <= T_max;
    cos(delta_max) * norm(U(k, :)) <= U(k, 1);
end

% Trust regions:
for k = 1:K
    dx = X(k, :) - X_last(k, :);
    du = U(k, :) - U_last(k, :);
    dx * dx' + du * du' <= delta(k);
end
ds = sig - sigma_last;
norm(ds, 1) <= delta_s;

disp("Solving problem.")

% -------------------------------------------------------------------------
cvx_end

x = full(X);
u = U;
s = sig;
delta_cost = norm(delta);
nu_cost = norm(nu, 1);
d = (norm(delta) < delta_tol) && (norm(nu, 1) < nu_tol);

fprintf("sigma: %0.5f \n", sig)
fprintf("delta_cost: %0.5f \n", delta_cost)
fprintf("nu_cost: %0.5f \n", nu_cost)


end

