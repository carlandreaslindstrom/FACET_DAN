function [ A, mu, sigma ] = gaussianFit( X, Y, fast, guess )

    if ~exist('guess','var') || ~numel(guess) 
        if ~exist('fast','var') || ~fast
            guess(1) = max(Y);
            guess(2) = sum(X.*Y)/sum(Y);  % mean
            guess(3) = sqrt( sum((X.^2).*Y)/sum(Y) - guess(2)^2); % sigma
        else
            [~, x1] = max(Y(Y <= max(Y)/2));
            [guess(1), guess(2)] = max(Y);
            guess(3) = abs(guess(2) - x1);
        end
    end
    [~, result] = evalc('fminsearch(@(params) mygaussfit2(params, X, Y), guess);');

    sigma = abs(result(3));
    mu = result(2);
    A = result(1);

    function S = mygaussfit2(p, X, Y)

        S = sum( ( p(1) * exp(-(1/2) * ((X - p(2))/p(3)).^2) - Y ).^2 );

        % visu (comment when running)
        if false
            axis([min(X) max(X) min(Y) max(Y)]);
            f_x = p(1) * exp(-(1/2) * ((X - p(2))/p(3)).^2);
	    plot(X, f_x, '-r');
	    hold on;        % Gaussian


	    plot(X, Y, '-xb');
	    hold off;
	    legend('gauss fit', 'dist');
	    grid on;
	    pause(0.01);
	end% if
    end

end
