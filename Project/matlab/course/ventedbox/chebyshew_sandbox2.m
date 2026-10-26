%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Chebyshew alignment with QL = 5-20%
% Authur: Niels Iversen %
% Institutuion: Technical Univesity of Denmark %
clear all

tic
rho = 1.18;
c = 345;


for i = 1:160
   
   % Ripple parameters 
   k(i) = 0.2+(i/2-0.5)/100; 
   e(i) = (sinh(4*atanh(k(i))))^(-1);
   dBrip(i) = 10*log10(1+e(i)^2);
   
   D(i) = (k(i)^4 + 6*k(i)^2 + 1) / 8;
   
   % Coefficients related to the magnitude squared function
   A1(i) = -2*((64*e(i)^2)/(1+e(i)^2))^(1/4);
   A2(i) = 1.25*((64*e(i)^2)/(1+e(i)^2))^(1/2);
   A3(i) = -0.25*((64*e(i)^2)/(1+e(i)^2))^(3/4);
   a1(i) = (k(i)*sqrt(4+2*sqrt(2)))/(D(i)^(1/4));
   a2(i) = (1+k(i)^2*(1+sqrt(2)))/(D(i)^(1/2));
   a3(i) = (a1(i)/(D(i)^(1/2))) * (1-((1-k(i)^2)/(2*sqrt(2))));
   
   % Solving fourth order polynoms:
    syms x
    % Solving for d
    roots = solve(x^4-A3(i)*x^3-A2(i)*x^2-A1(i)*x-1,x);
    for t = 1:size(roots)
         if imag(roots(t))==0 & roots(t) > 0;
            d_arr(i) = double(roots(t));
         end
    end
    
    for j = 1:16;
        QL = 4+j;
        syms x
        % Solving for r and calculating Qts values
        roots = solve(x^4-(a3(i)*QL)*x^3+(a1(i)*QL)*x-1,x);
        for t = 1:size(roots)
            temp(t) = (roots(t)^2*QL)/(a1(i)*roots(t)*QL-1);
            if temp(t) > 0 & temp(t) < 2 & imag(roots(t))==0 & roots(t) > 0
                r_arr(j,i) = double(roots(t));
                Qts_arr(j,i) = double(temp(t));
            end
        end
        % Calculating tuning parameters alpha, q and h. 
        alpha_arr(j,i) = r_arr(j,i)^2*(a2(i)-(1/(QL*Qts_arr(j,i)))-r_arr(j,i)^2)-1;
        q_arr(j,i) = r_arr(j,i)*sqrt(d_arr(i));
        h_arr(j,i) = r_arr(j,i)^2;
    end
    
end
toc



