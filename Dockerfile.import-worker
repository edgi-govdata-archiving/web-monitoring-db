FROM envirodgi/db-generic
MAINTAINER enviroDGI@gmail.com

ENV QUEUE=*
ENV VERBOSE=1

CMD ["bundle", "exec", "rake", "environment", "resque:work"]
