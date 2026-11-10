function c = lab_vcolor(v)
% LAB_VCOLOR  The kit's verdict colours: OK green, CHECK orange, BAD red, anything else grey.
switch v
    case 'OK',    c = [0 0.55 0];
    case 'CHECK', c = [0.9 0.5 0];
    case 'BAD',   c = [0.85 0 0];
    otherwise,    c = [0.6 0.6 0.6];
end
end
