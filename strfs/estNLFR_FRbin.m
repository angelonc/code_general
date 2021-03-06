function [x_orig,y_orig,mdl,ahat,p,dm,mdli] = estNLFR3(fr,frh,npoints,thresh);

%% function [x,y,mdl,ahat,p] = estNLFR(fr,frh,pct,thresh);
%
% this function fits an exponential to predicted versus measured
% firing rates to estimate a neurons nonlinearity. for cleanliness,
% removes outliers using Mahalanobis distance
%
% INPUT:
%  fr: actual firing rate
%  frh: predicted firing rate (should be same sampling as fr)
%  npoints: number of histogram samples to use
%  thresh: Mahalanobis distance threshold
%
% OUTPUT:
%  x: prediction bins
%  y: binned fr
%  mdl: function handle for exponential
%  ahat: model parameters from fitting
%  p: various parameters for each fit (start and end values, zero values, slopes, etc)

warning off

% smooth estimate and original fr
%fr = SmoothGaus(fr,3);
%frh = SmoothGaus(frh,3);

% by default, do point matching
x = frh;
y = fr;

if exist('npoints','var')
    
    % if specified, do histogram equalization (sort of)
    if ~isempty(npoints)

        %% sort the firing rates
        sortBins = unique(sort(fr));

        % generate bins
        % (does this by first finding unique rate values, then uniformly
        % divides them into npoints bins)
        ndata = round((1/npoints)*length(fr));
        edges = sortBins(1:ndata:end);
                   
         % find mean frh for each bin
        [n,~,bins] = histcounts(fr,edges);
        %[~,edges,bins] = histcounts(fr,2000);
        nl = zeros(1,max(bins));
        for i = 1:length(nl)
            nl(i) = mean(frh(bins == i));
        end
        centers = edges(1:end-1) + diff(edges)/2;
        y = centers(1:end);
        x = nl(1:end);
                
    end
    
end


% outlier detection
if exist('thresh','var')
    % compute Mahalanobis distance
    m = [mean(x) mean(y);mean(x) mean(y)];
    Y = [x' y'];
    dm = mahal(Y,Y);

    % remove outliers based on distance
    x_orig = x;
    y_orig = y;
    ind = dm < thresh;
    x = x(ind);
    y = y(ind);
    n = n(ind);
else
    dm = [];
    x_orig = x;
    y_orig = y;
    n = n;
end

% fit nonlinearity
mdl = @(a,x)( a(1) + a(2) .* exp((x.*a(3))) );
mdli = @(a,y)( log((y-a(1))./a(2)) ./ a(3) );
a0 = [0.1;.1;3];
[ahat,r,J,cov,mse] = nlinfit(x,y,mdl,a0,'Weights',n);

% compute some parameters
x1 = x(1);
x2 = x(end);
p.y1 = mdl(ahat,x1);
p.yend = mdl(ahat,x2);
p.y0 = mdl(ahat,0);

% slope from y0 to max
p.slope0x = (p.yend - p.y0) / (x2-0);

% slope from bottom to top
p.slopeAll = (p.yend-p.y1) / (x2-x1);

% offset
p.offset = ahat(1) + ahat(2);

% baseline
p.baseline = mdl(ahat,-10000);

% slope from 0 to 2
y2 = mdl(ahat,2);
p.slope02 = (y2-p.y0) / (2-0);

% slop from 0 to 1
y1 = mdl(ahat,1);
p.slope01 = (y1-p.y0) / (1-0);

%  hold on
%  scatter(x,y)
%  x1 = linspace(min(x),max(x),100);
%  y1 = mdl(ahat,x1);
%  plot(x1,y1);