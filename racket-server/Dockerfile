FROM racket/racket:latest

WORKDIR /app

RUN apt-get update && apt-get install -y xvfb

RUN raco pkg install --auto web-server
RUN raco pkg install --auto redex
RUN raco pkg install --auto hosted-minikanren

# Keep module-relative imports into the strict matrix and shared providers valid.
COPY src/ src/
COPY derivations/strict-search/shared/ derivations/strict-search/shared/
COPY derivations/strict-search/matrix/ derivations/strict-search/matrix/

ENV PLTSTDERR=error
ENV DISPLAY=:99

EXPOSE 5000

CMD xvfb-run -a racket src/app.rkt
