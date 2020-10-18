FROM kxsys/embedpy as base

ENV Q_TICKHOME=/opt/kx/kdb-tick

RUN mkdir -p $Q_TICKHOME/tick

RUN chmod 774 $Q_TICKHOME && \
    chmod 774 $Q_TICKHOME/tick && \
    chown -R kx:kx $Q_TICKHOME

COPY --chown=kx docker/tick.sh $Q_TICKHOME
COPY --chown=kx kdb-tick/*.q $Q_TICKHOME
COPY --chown=kx kdb-tick/tick/*.q $Q_TICKHOME/tick

ENTRYPOINT ["/init"]
CMD ["/opt/kx/kdb-tick/tick.sh"]