%% =========================================================
% 3D TIME-INDEPENDENT SCHRODINGER EQUATION
% Finite Difference Method
%
% Particle confined in a spherical finite-potential quantum dot
%
% Solves:
%
% [-hbar^2/(2m) * nabla^2 + V(x,y,z)] psi = E psi
%
% Outputs:
%   1. Lowest energy eigenvalues
%   2. 2D probability-density maps
%   3. 3D probability-density isosurfaces
%
% =========================================================

clear;
clc;
close all;

fprintf('=============================================\n');
fprintf('  3D SCHRODINGER EQUATION SOLVER\n');
fprintf('  Finite Difference Method\n');
fprintf('=============================================\n\n');


%% =========================================================
% 1. PHYSICAL CONSTANTS
% =========================================================

hbar = 1.054571817e-34;       % Reduced Planck constant [J s]
m0   = 9.1093837139e-31;      % Electron rest mass [kg]
eV   = 1.602176634e-19;       % 1 eV [J]


%% =========================================================
% 2. PARTICLE PARAMETERS
% =========================================================

% Effective mass
% For a free electron:
m_eff = 1.0 * m0;

% If modelling a semiconductor, replace with:
% m_eff = 0.13 * m0;   % Example electron effective mass


%% =========================================================
% 3. SIMULATION DOMAIN
% =========================================================

Lx = 5e-9;                    % Domain length x [m]
Ly = 5e-9;                    % Domain length y [m]
Lz = 5e-9;                    % Domain length z [m]

% Number of grid points
Nx = 25;
Ny = 25;
Nz = 25;

x = linspace(-Lx/2,Lx/2,Nx);
y = linspace(-Ly/2,Ly/2,Ny);
z = linspace(-Lz/2,Lz/2,Nz);

dx = x(2)-x(1);
dy = y(2)-y(1);
dz = z(2)-z(1);

fprintf('Grid:\n');
fprintf('Nx = %d\n',Nx);
fprintf('Ny = %d\n',Ny);
fprintf('Nz = %d\n',Nz);

fprintf('Grid spacing:\n');
fprintf('dx = %.4f nm\n',dx*1e9);
fprintf('dy = %.4f nm\n',dy*1e9);
fprintf('dz = %.4f nm\n\n',dz*1e9);


%% =========================================================
% 4. CREATE 3D GRID
% =========================================================

% IMPORTANT:
% ndgrid is used for the numerical Hamiltonian.

[X,Y,Z] = ndgrid(x,y,z);


%% =========================================================
% 5. DEFINE QUANTUM DOT
% =========================================================

% Quantum-dot radius
R = 2e-9;                    % 2 nm

% Potential barrier
V0 = 10 * eV;                % 10 eV

% Start with barrier everywhere
V = V0 * ones(Nx,Ny,Nz);

% Spherical quantum dot
inside = (X.^2 + Y.^2 + Z.^2) <= R^2;

% Potential inside quantum dot
V(inside) = 0;


%% =========================================================
% 6. DISPLAY POTENTIAL INFORMATION
% =========================================================

fprintf('Quantum dot parameters:\n');
fprintf('Radius = %.3f nm\n',R*1e9);
fprintf('Barrier = %.3f eV\n',V0/eV);
fprintf('Effective mass = %.3f m0\n\n',m_eff/m0);


%% =========================================================
% 7. INTERIOR GRID POINTS
% =========================================================

% Wavefunction is taken to be zero at the outer boundaries.

ix = 2:Nx-1;
iy = 2:Ny-1;
iz = 2:Nz-1;

Nx_i = length(ix);
Ny_i = length(iy);
Nz_i = length(iz);

N = Nx_i * Ny_i * Nz_i;

fprintf('Interior grid points = %d\n\n',N);


%% =========================================================
% 8. 1D SECOND-DERIVATIVE MATRICES
% =========================================================

% X direction
ex = ones(Nx_i,1);

Dx2 = spdiags( ...
    [ex -2*ex ex], ...
    -1:1, ...
    Nx_i,Nx_i) / dx^2;


% Y direction
ey = ones(Ny_i,1);

Dy2 = spdiags( ...
    [ey -2*ey ey], ...
    -1:1, ...
    Ny_i,Ny_i) / dy^2;


% Z direction
ez = ones(Nz_i,1);

Dz2 = spdiags( ...
    [ez -2*ez ez], ...
    -1:1, ...
    Nz_i,Nz_i) / dz^2;


%% =========================================================
% 9. IDENTITY MATRICES
% =========================================================

Ix = speye(Nx_i);
Iy = speye(Ny_i);
Iz = speye(Nz_i);


%% =========================================================
% 10. CONSTRUCT 3D LAPLACIAN
% =========================================================

Laplacian = ...
      kron(Iz,kron(Iy,Dx2)) ...
    + kron(Iz,kron(Dy2,Ix)) ...
    + kron(Dz2,kron(Iy,Ix));


%% =========================================================
% 11. POTENTIAL MATRIX
% =========================================================

V_inner = V(ix,iy,iz);

V_vector = V_inner(:);

V_matrix = spdiags( ...
    V_vector, ...
    0, ...
    N,N);


%% =========================================================
% 12. KINETIC ENERGY OPERATOR
% =========================================================

T = -(hbar^2/(2*m_eff)) * Laplacian;


%% =========================================================
% 13. HAMILTONIAN
% =========================================================

H = T + V_matrix;

fprintf('Hamiltonian size: %d x %d\n',N,N);

fprintf('Hamiltonian constructed successfully.\n\n');


%% =========================================================
% 14. SOLVE EIGENVALUE PROBLEM
% =========================================================

% Number of eigenstates requested
num_states = 6;

fprintf('Calculating lowest %d eigenstates...\n\n',num_states);

% eigs finds the lowest-energy states
[Psi,E_matrix] = eigs( ...
    H, ...
    num_states, ...
    'smallestreal');


%% =========================================================
% 15. EXTRACT EIGENVALUES
% =========================================================

E = real(diag(E_matrix));


%% =========================================================
% 16. SORT ENERGY LEVELS
% =========================================================

[E,order] = sort(E);

Psi = Psi(:,order);


%% =========================================================
% 17. CONVERT ENERGY TO eV
% =========================================================

E_eV = E / eV;


%% =========================================================
% 18. DISPLAY ENERGY LEVELS
% =========================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       LOWEST ENERGY EIGENVALUES\n');
fprintf('=============================================\n');

for n = 1:num_states

    fprintf( ...
        'State %d : %.9f eV\n', ...
        n,E_eV(n));

end

fprintf('=============================================\n\n');


%% =========================================================
% 19. RECONSTRUCT AND NORMALIZE WAVEFUNCTIONS
% =========================================================

for n = 1:num_states

    fprintf('Processing state %d...\n',n);


    %% -----------------------------------------------------
    % Reconstruct 3D wavefunction
    %% -----------------------------------------------------

    psi = zeros(Nx,Ny,Nz);

    psi(ix,iy,iz) = reshape( ...
        Psi(:,n), ...
        [Nx_i,Ny_i,Nz_i]);


    %% -----------------------------------------------------
    % Normalize wavefunction
    %% -----------------------------------------------------

    probability = abs(psi).^2;

    normalization = ...
        sum(probability(:)) * dx * dy * dz;

    psi = psi / sqrt(normalization);


    %% -----------------------------------------------------
    % Probability density
    %% -----------------------------------------------------

    density = abs(psi).^2;


    %% =====================================================
    % 20. 2D CENTRAL SLICE
    % =====================================================

    midz = round(Nz/2);

    figure('Name', ...
        sprintf('State %d - 2D Probability Density',n), ...
        'Color','w');

    imagesc( ...
        x*1e9, ...
        y*1e9, ...
        density(:,:,midz)');

    axis image;

    xlabel('x (nm)');
    ylabel('y (nm)');

    title(sprintf( ...
        'State %d: |\\psi(x,y,z=0)|^2, E = %.6f eV', ...
        n,E_eV(n)));

    colorbar;

    set(gca,'FontSize',11);


    %% =====================================================
    % 21. X-Z CENTRAL SLICE
    % =====================================================

    midy = round(Ny/2);

    figure('Name', ...
        sprintf('State %d - XZ Probability Density',n), ...
        'Color','w');

    imagesc( ...
        x*1e9, ...
        z*1e9, ...
        squeeze(density(:,midy,:))');

    axis image;

    xlabel('x (nm)');
    ylabel('z (nm)');

    title(sprintf( ...
        'State %d: |\\psi(x,y=0,z)|^2', ...
        n));

    colorbar;

    set(gca,'FontSize',11);


    %% =====================================================
    % 22. Y-Z CENTRAL SLICE
    % =====================================================

    mIdx = round(Nx/2);

    figure('Name', ...
        sprintf('State %d - YZ Probability Density',n), ...
        'Color','w');

    imagesc( ...
        y*1e9, ...
        z*1e9, ...
        squeeze(density(mIdx,:,:))');

    axis image;

    xlabel('y (nm)');
    ylabel('z (nm)');

    title(sprintf( ...
        'State %d: |\\psi(x=0,y,z)|^2', ...
        n));

    colorbar;

    set(gca,'FontSize',11);


    %% =====================================================
    % 23. 3D ISOSURFACE
    % =====================================================

    % -----------------------------------------------------
    % IMPORTANT FIX
    %
    % The numerical calculation uses ndgrid.
    %
    % isosurface/isonormals work naturally with meshgrid.
    %
    % Therefore:
    %   1. Create meshgrid coordinates
    %   2. Permute density from ndgrid ordering
    % -----------------------------------------------------

    [Xm,Ym,Zm] = meshgrid( ...
        x*1e9, ...
        y*1e9, ...
        z*1e9);


    % Convert:
    %
    % Nx x Ny x Nz
    %
    % into:
    %
    % Ny x Nx x Nz

    density_mesh = permute( ...
        density, ...
        [2 1 3]);


    %% -----------------------------------------------------
    % Isosurface level
    %% -----------------------------------------------------

    isoLevel = ...
        0.15 * max(density_mesh(:));


    %% -----------------------------------------------------
    % Create 3D figure
    %% -----------------------------------------------------

    figure('Name', ...
        sprintf('State %d - 3D Wavefunction',n), ...
        'Color','w');


    %% -----------------------------------------------------
    % Generate isosurface
    %% -----------------------------------------------------

    p = patch( ...
        isosurface( ...
            Xm, ...
            Ym, ...
            Zm, ...
            density_mesh, ...
            isoLevel));


    %% -----------------------------------------------------
    % Calculate surface normals
    %
    % This is the corrected part.
    %% -----------------------------------------------------

    isonormals( ...
        Xm, ...
        Ym, ...
        Zm, ...
        density_mesh, ...
        p);


    %% -----------------------------------------------------
    % Surface appearance
    %% -----------------------------------------------------

    p.FaceColor = 'interp';
    p.EdgeColor = 'none';


    %% -----------------------------------------------------
    % Axis labels
    %% -----------------------------------------------------

    xlabel('x (nm)');
    ylabel('y (nm)');
    zlabel('z (nm)');


    %% -----------------------------------------------------
    % Title
    %% -----------------------------------------------------

    title(sprintf( ...
        '3D Probability Density | State %d | E = %.6f eV', ...
        n,E_eV(n)));


    %% -----------------------------------------------------
    % Graphics settings
    %% -----------------------------------------------------

    axis equal;
    axis tight;

    grid on;

    view(3);

    camlight;
    lighting gouraud;

    set(gca,'FontSize',11);


end


%% =========================================================
% 24. ENERGY LEVEL DIAGRAM
% =========================================================

figure('Name','Energy Levels','Color','w');

hold on;

for n = 1:num_states

    plot( ...
        [0.2 0.8], ...
        [E_eV(n) E_eV(n)], ...
        'LineWidth',2);

    text( ...
        0.85, ...
        E_eV(n), ...
        sprintf('E_%d = %.6f eV',n,E_eV(n)), ...
        'VerticalAlignment','middle');

end

hold off;

xlim([0 1.5]);

ylim([0 max(E_eV)*1.15]);

ylabel('Energy (eV)');

title('Lowest Energy Eigenstates');

set(gca, ...
    'XTick',[], ...
    'FontSize',11);

grid on;


%% =========================================================
% 25. SAVE RESULTS
% =========================================================

results.E_J = E;
results.E_eV = E_eV;
results.Psi = Psi;

results.x = x;
results.y = y;
results.z = z;

results.X = X;
results.Y = Y;
results.Z = Z;

results.V = V;

results.R = R;
results.V0 = V0;

results.m_eff = m_eff;

results.hbar = hbar;

save('Schrodinger_3D_results.mat','results');


%% =========================================================
% 26. FINAL MESSAGE
% =========================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       SIMULATION COMPLETED SUCCESSFULLY\n');
fprintf('=============================================\n');

fprintf('Results saved to:\n');
fprintf('Schrodinger_3D_results.mat\n\n');

fprintf('Generated:\n');
fprintf('  - Energy eigenvalues\n');
fprintf('  - 2D XY probability densities\n');
fprintf('  - 2D XZ probability densities\n');
fprintf('  - 2D YZ probability densities\n');
fprintf('  - 3D probability-density isosurfaces\n');
fprintf('  - Energy-level diagram\n');

fprintf('=============================================\n');