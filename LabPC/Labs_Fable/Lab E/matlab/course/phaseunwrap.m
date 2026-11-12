function phiu=phaseunwrap(phiw,d,f)

%  function phiu=phaseunwrap(phiw,d,f)
%                unwraps the phase phiw
%                compensates for measurement distance, d.
%  input :
%
%  phiw [degrees]: the (wrapped) phase 
%  d    [meters] : measurement distance 
%  f    [Hz]     : measurement frequencies
%
%  if d,f are specified the phase is compensated for the delay caused by the 
%  measurement distance d before unwrapping.
%  
%  Output :
%
%  phiu  [degrees] :  the unwrapped phase in degrees 
%                     (for use in efreqconv)
%  
%  Run as phaseunwrap(0) for demo
%
%  Finn Agerkvist  March 2004, May 2005, Nov 2007

c=345;
n=max(size(phiw));

% Make two row vectors (VCH 2020):
bbb=zeros(1,n);bbb(1,:)=phiw(:);phiw=bbb;
bbb=zeros(1,n);bbb(1,:)=f(:);f=bbb;

if nargin<3

   f=1:n;
   if nargin<2
      d=0;
  end
end


if phiw==0
    
    dr=0.7
    n=24;
    n2=10*n;
    f=20*2.^((0:n2)/n);
    phiorg=2*pi*(-f*dr/c+0.399*sin(sqrt(f)/5));
    phiw=180/pi*angle(exp(j*phiorg));
    
    
end
%f
k=pi/180;

phicr=k*phiw+2*pi*f*d/c;
phiu=unwrap(phicr,1*pi)/k;


semilogx(f,phiw,f,phiu)
%semilogx(f,phiw)
legend('wrapped (org)','unwrapped')
title('Phase (degrees)')
