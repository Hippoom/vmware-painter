FROM ruby:2.2-onbuild

#see https://github.com/docker-library/ruby/blob/5d04363db6f7ae316ef7056063f020557db828e1/2.2/onbuild/Dockerfile

ENV PAINTER_EXECUTABLE lib/painter.rb
ENV PAINTER_CONFIG_DIR /etc/scaleworks/graph
ENV PAINTER_CONFIG_FILE vmware.yml

RUN chmod +x docker-entry-point.sh

ENTRYPOINT [ "./docker-entry-point.sh" ]
