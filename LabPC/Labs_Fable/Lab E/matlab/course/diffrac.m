function [t,imp_resp,f,Imp1]=diffrac(corners,r,angles,source_rad,fs);

% [t,imp_resp,f,Imp1]=diffrac(corners,r,angles,source_rad,fs)
%
% Diffraction calulation for loudspeaker front plate design.
% Calculation according to Terai T., Journal of Sound and Vibration, 1980, 69(1),
% 71-100. "On calculation of sound fields around three dimensional objects
% by integration". The paper assumes an infinitely thin baffle and ignores
% any contributions from a pressure on the back of the baffle
%
% The baffle is assumed placed in xy plane (z=0) and source is assumed to be
% centered in (0,0) in this plane. 
%
% Input parameters:
%
% corners      : matrix of corner positions:
%                1st column: x coordinate
%                2nd column: y coordinate
%                3rd column: z coordinate (if omitted, zero is assumed)
%                f.ex.   [ 1 1 0; 1 -1 0; -1 -1 0; -1 1 0; 1 1 0]
%                The function will fill the straight line between corners
%                based on fs. For curved boundary, use more corners; a
%                polygon is created that approximates the curve. More
%                sources provide better results (e.g. use >100).
% 
% r            : source-receiver distance. On axis mic position is (0,0,r)
%
% angles       : [azimuth elevation] horizontal and vertical off axis angle
%                 in degrees. Can contain more rows with more positions,
%                 all are calculated.
%
% source_rad   : piston source radius.
% 
% 
% fs           : sampling frequency in the calculation, edge element size
%                is adjusted accordingly. Default value 44100 Hz
%
% Output parameters:
%
% t            : time axis for the simulated impulse response
%
% imp_resp     : simulated impulse response
%
% f            : frequency axis for the simulated frequency response
%
% Imp1         : frequency response


%     Finn Agerkvist, 2017
%     VCH 2019, some improvements in the input/output
%     VCH 2024, some coding and help improvements

if nargin<5
    if nargin<4
        if nargin<3
            if nargin<2
                if nargin<1
                    lx=0.1; ly=0.15;
                    corners=[lx ly; lx -ly; -lx -ly; -lx ly; lx ly]
                end
                r=1
            end
            angles=[ 0 0 ; 30 0] % [horizontal and vertical]
        end
        source_rad=0.04 % 4 inch driver 
    end
    fs=44100

end


c=343;
dt=1/fs;
delta_e_max=c/fs/2;

%angles 
n_ang=size(angles,1);


%sources
[sources,strength]=pistonsource(source_rad,delta_e_max);


n_source=size(sources,1);
if size(sources,2)==2
  sources=[sources zeros(n_source,1)];
end
%s=[s zeros(n_source,1)]
maxSr=max(sqrt(sum(sources.^2,2)));  % maximum radius of source element
maxCr=max(sqrt(sum(corners.^2,2)));  % maximum radius of corner elements

%edge elements
n_edge=size(corners,1)-1;
if size(corners,2)==2
  corners=[corners zeros(n_edge+1,1)];
end

% Order corner sources clockwise and force that the last corner source is
% at the same place as the first (VCH 10-2019)
[dum,cornerI]=sort(angle([corners(:,1)+1i*corners(:,2)]),'descend');
corners=corners(cornerI,:);
if abs(corners(1,1)-corners(end,1))>maxCr*1e-6 | abs(corners(1,2)-corners(end,2))>maxCr*1e-6 | abs(corners(1,3)-corners(end,3))>maxCr*1e-6
    corners=[corners; corners(1,:)];
end


figure%(6)
plot(corners(:,1),corners(:,2),'-',sources(:,1),sources(:,2),'.');
axis([-1.1*maxCr 1.1*maxCr -1.1*maxCr 1.1*maxCr])
legend('edge','source')
axis equal
grid on


d_e=[];
nes=[];
E=[];
maxSr=dt*c*ceil(maxSr/(dt*c));  % time align for source center
dmin=r-maxSr-5*c*dt;  % add 5 samples for safety
dmax=r+maxSr+2*maxCr;

T=(dmax-dmin)/c;
Nmin=2^ceil(log(fs/20)/log(2));
N=2^ceil(log(T*fs)/log(2));
N=max(N,Nmin);
t=(dmin-r)/c+(0:dt:(N-1)*dt);
st=length(t);

for n=1:n_edge
   ne=ceil(norm(corners(n+1,:)-corners(n,:))/delta_e_max); % number of elements
   nes=[nes ; ne]; % number of elements pr edge
   de=(corners(n+1,:)-corners(n,:))/ne;   % vector of edge element vectors 
   d_e=[d_e; ones(ne,1)*de];
   en=ones(ne,1)*corners(n,:)+ (0.5:(ne-0.5))'*de;
   E=[E; en] ;  % edge element location vector
end

N_edge=sum(nes); 
impi=[];
ones_NE=ones(N_edge,1);



for n=1:n_ang
    imp=zeros(1,st);
    theta=pi*angles(n,1)/180;
    phi=pi*angles(n,2)/180;
    
    r_theta=r*[ cos(phi)*sin(theta) sin(phi)  cos(phi)*cos(theta)     ];
    
    for k=1:n_source
        
        dm=norm(sources(k,:)-r_theta);  %  sourcer reciver distance
        nt0=(dm-dmin)/c/dt;
        S=ones_NE*sources(k,:);
        R=ones(N_edge,1)*r_theta;
        l=R-E;
        m=E-S;
        lm=sqrt(sum(l'.^2)'.*sum(m'.^2)'); 
        nt=(sqrt(sum(l'.^2))'+sqrt(sum(m'.^2))'-dmin)/c/dt; %time corrected delay (source center)
        
        %Terai
        pdc=cross(l,m,2);
        pdot=dot(pdc,d_e,2);
        naevner=sqrt(sum(l'.^2).*sum(m'.^2))'+dot(l,m,2);
        pd=strength(k)*r/2/pi*(pdot./naevner)./lm;
        
        % direct sound
        if R(1,3)>=0
            k;
            j0=floor(nt0);
            xd=nt0-j0;
            imp(j0+1)=imp(j0+1)+(1-xd)*2*r/dm*strength(k);
            imp(j0+2)=imp(j0+2)+xd*2*r/dm*strength(k);
        end
                
%         ind_fl=floor(nt)
%         x=nt-ind_fl
%         imp(ind_fl+1)=imp(ind_fl+1)+(1-x).*pd;
%         imp(ind_fl+2)=imp(ind_fl+2)+x.*pd;
        for i=1:N_edge
            j=floor(nt(i));
            x=nt(i)-j;
            imp(j+1)=imp(j+1)+(1-x)*pd(i);
            imp(j+2)=imp(j+2)+x*pd(i);
        end
        
    end
    if k==0
        impi=imp';
    else
        impi=[impi imp'];
    end
end
imp_resp=impi;

st2=floor(st/2);
f=(1:st2)*fs/2/st2;

% figure(1)
for i=1:n_ang
   figure
   subplot(2,1,1)
   plot(t*1000,[imp_resp(:,i)])
   xlabel('t [ms]')
   minp=min(imp_resp(:,i));
   maxp=max(imp_resp(:,i));
   tmax=(dmax-r)/c*1000;
   axis([-0.2 tmax  minp-0.1 maxp+.2]);
   tstr=sprintf('Observation angles: %5.1f, %5.1f degrees, sum=%5.3f',angles(i,1),angles(i,2),sum(imp_resp(:,i)));
   tstr=sprintf('Observation angles: %5.1f, %5.1f degrees',angles(i,1),angles(i,2));
   title(tstr);
   grid on
   subplot(2,1,2)
   Imp=fft(imp_resp(:,i));
   Imp1(:,i)=20*log10(abs(Imp(1:st2)));
   semilogx(f,Imp1(:,i))
   %legend('On axis','30 degrees off axis')
   xlabel('Frequency [Hz]');
   ylabel('Sound pressure level re free field');
   title('Response including effect of baffle')
   axis([20 20000 -6 12])
%    if (n_ang>1) & (i<n_ang) 
%        s='press key for next plot'
%        pause
%    end
   grid on
end


function [ sources,strength ] = pistonsource(radius,dmax)
%  [ sources,strength ] = pistonsource(radius,dmax)
%   Calculates equivalent monopole sources for a circular piston
%   sources : monopole positions
%   strength: monopole strengh (sum=1)
%   radius  : piston radius
%   dmax    : max distance between monopole sources
% Finn Agerkvist, 2017

Nr=ceil(radius/dmax);

dr=radius/(Nr+0.5);

sources=[ 0 0 ];
strength=[(dr/radius)^2/4];
for n=1:Nr
    rc=n*dr;  % radius for center of ring
    na=ceil(2*pi*(n+0.5)*dr/dmax);
    na=max(na,4);%  number of angles
    dphi=2*pi/na;
    strth=((n+0.5)^2-(n-0.5)^2)/(Nr+0.5)^2/na;
    for a=1:na
        sources=[sources; rc*cos(a*dphi) rc*sin(a*dphi) ];
        strength=[strength; strth];
    end
end

